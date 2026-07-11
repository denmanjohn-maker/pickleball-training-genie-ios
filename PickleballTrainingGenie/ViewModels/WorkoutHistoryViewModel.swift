import Foundation
import SwiftUI

/// A single row in the training-history timeline: either a full workout session
/// or an individual drill mastered from the drill library.
enum TrainingHistoryEntry: Identifiable {
    case workout(WorkoutSessionResponse)
    case drill(DrillProgressItem)

    var id: String {
        switch self {
        case .workout(let session): return "workout-\(session.id)"
        case .drill(let item): return "drill-\(item.drillId)"
        }
    }

    var date: Date? {
        switch self {
        case .workout(let session): return APIDateParsing.parse(session.completedAt)
        case .drill(let item): return item.completedAt.flatMap(APIDateParsing.parse)
        }
    }
}

/// Parses ISO 8601 timestamps from the API, with or without fractional seconds.
enum APIDateParsing {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain = ISO8601DateFormatter()

    static func parse(_ raw: String) -> Date? {
        if let date = fractional.date(from: raw) ?? plain.date(from: raw) {
            return date
        }
        // The backend emits microsecond precision (e.g. ".440282Z"), which
        // ISO8601DateFormatter can reject — retry with the fraction stripped.
        if let dotIndex = raw.firstIndex(of: ".") {
            let stripped = String(raw[..<dotIndex]) + (raw.hasSuffix("Z") ? "Z" : "")
            return plain.date(from: stripped)
        }
        // No timezone suffix at all (unspecified DateTimeKind): assume UTC.
        return plain.date(from: raw + "Z")
    }

    static func display(_ raw: String) -> String {
        guard let date = parse(raw) else { return raw }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

@MainActor
class WorkoutHistoryViewModel: ObservableObject {
    @Published var sessions: [WorkoutSessionResponse] = []
    @Published var drillCompletions: [DrillProgressItem] = []
    @Published var totalSessionCount = 0
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private var page = 1
    private let pageSize = 20
    private let client: PickleballTrainingGenieClient

    init(client: PickleballTrainingGenieClient) {
        self.client = client
    }

    var hasMoreSessions: Bool { sessions.count < totalSessionCount }

    /// Workouts and drill completions merged into one timeline, newest first.
    var timeline: [TrainingHistoryEntry] {
        let entries = sessions.map(TrainingHistoryEntry.workout)
            + drillCompletions.map(TrainingHistoryEntry.drill)
        return entries.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    var totalMinutesTrained: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    var drillsMasteredCount: Int { drillCompletions.count }

    func load() async {
        isLoading = true
        errorMessage = nil
        page = 1
        do {
            async let sessionsTask = client.workoutSessions(page: 1, pageSize: pageSize)
            async let progressTask = client.drillProgress()
            let (sessionList, progress) = try await (sessionsTask, progressTask)
            sessions = sessionList.items
            totalSessionCount = sessionList.totalCount
            drillCompletions = progress
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 404:
                errorMessage = "The server doesn't support training history yet."
            case .invalidResponse(let code) where code == 401:
                errorMessage = "Please sign in again to see your history."
            default:
                errorMessage = "Could not load your training history."
            }
        } catch {
            errorMessage = "Could not load your training history: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func loadMore() async {
        guard hasMoreSessions, !isLoadingMore else { return }
        isLoadingMore = true
        do {
            let response = try await client.workoutSessions(page: page + 1, pageSize: pageSize)
            sessions.append(contentsOf: response.items)
            totalSessionCount = response.totalCount
            page += 1
        } catch {
            // Silent; the user can pull to refresh.
        }
        isLoadingMore = false
    }
}
