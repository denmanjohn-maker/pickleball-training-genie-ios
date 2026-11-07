import Foundation

/// Loads workout-session dates for the streak / weekly-goal display on the
/// Today, Progress, and Profile habit cards. Unlike the history screen (which shows whatever pages
/// are loaded), the streak number is only honest if it's provably complete —
/// so this pages until a loaded session falls outside both the streak window
/// and the current week, then caches the dates for offline display.
///
/// Matches `WorkoutHistoryViewModel` semantics: workout sessions only —
/// individual drill completions don't extend the streak.
@MainActor
final class TrainingStreakStore: ObservableObject {
    @Published private(set) var sessionDates: [Date] = []
    @Published private(set) var isLoading = false
    /// Non-nil when the numbers come from the offline cache (network failed).
    @Published private(set) var cachedDate: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasHistory = false
    @Published private(set) var statsDate: Date
    private var lastFetchedAt: Date?
    private var refreshPending = false
    private let now: () -> Date

    private let client: PickleballTrainingGenieClient
    private let cacheKey: String
    private let pageSize = 50
    /// Runaway guard (~500 sessions); a real streak never needs this much.
    private let maxPages = 10

    init(client: PickleballTrainingGenieClient, userId: String? = nil, now: @escaping () -> Date = Date.init) {
        self.client = client
        self.now = now
        statsDate = now()
        let scope = userId.map { "-\($0)" } ?? ""
        cacheKey = "trainingActivity\(scope)"
        if let entry = OfflineCache.load([Date].self, key: cacheKey) {
            sessionDates = entry.value
            cachedDate = entry.savedAt
            lastFetchedAt = entry.savedAt
            hasHistory = true
        }
    }

    var streakDays: Int {
        TrainingStats.currentStreakDays(sessionDates: sessionDates, now: statsDate)
    }

    var sessionsThisWeek: Int {
        TrainingStats.sessionsThisWeek(sessionDates: sessionDates, now: statsDate)
    }

    func refreshForCalendarChange() async {
        guard !Calendar.current.isDate(statsDate, inSameDayAs: now()) else { return }
        statsDate = now()
        await load()
    }

    func load(afterSave: Bool = false) async {
        if isLoading {
            // A save may land after the active request's snapshot was taken.
            refreshPending = refreshPending || afterSave
            return
        }
        isLoading = true
        repeat {
            refreshPending = false
            await fetchHistory()
        } while refreshPending
        isLoading = false
    }

    private func fetchHistory() async {
        errorMessage = nil
        statsDate = now()
        do {
            var dates: [Date] = []
            var loadedCount = 0
            var page = 1
            while true {
                let response = try await client.workoutSessions(page: page, pageSize: pageSize)
                loadedCount += response.items.count
                let parsed = response.items.compactMap {
                    APIDateParsing.parse($0.completedAt)
                }
                guard parsed.count == response.items.count else {
                    throw ActivityError.incomplete
                }
                dates.append(contentsOf: parsed)
                let couldChangeStats = unloadedSessionsCouldChangeStats(dates, now: statsDate)
                if loadedCount < response.totalCount,
                   response.items.isEmpty || (page == maxPages && couldChangeStats) {
                    throw ActivityError.incomplete
                }
                guard !response.items.isEmpty,
                      loadedCount < response.totalCount,
                      page < maxPages,
                      couldChangeStats
                else { break }
                page += 1
            }
            sessionDates = dates
            hasHistory = true
            cachedDate = nil
            lastFetchedAt = now()
            OfflineCache.save(dates, key: cacheKey)
        } catch {
            cachedDate = hasHistory ? lastFetchedAt : nil
            errorMessage = "Could not refresh training activity: \(error.localizedDescription)"
            AppLog.network.error("Training activity refresh failed: \(error.localizedDescription)")
        }
    }

    private enum ActivityError: LocalizedError {
        case incomplete
        var errorDescription: String? { "Training history is incomplete. Please try again." }
    }

    /// Sessions arrive newest-first, so everything unloaded is older than the
    /// oldest loaded session. An older session can still matter while every
    /// loaded one sits inside the current streak window (it could extend the
    /// streak) or inside the current week (it would miscount the weekly goal).
    /// Once a loaded session falls before both, the gap is proven and the
    /// numbers are final.
    private func unloadedSessionsCouldChangeStats(
        _ dates: [Date],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        guard let oldest = dates.min() else { return false }
        let oldestDay = calendar.startOfDay(for: oldest)

        if let week = calendar.dateInterval(of: .weekOfYear, for: now),
           oldestDay >= calendar.startOfDay(for: week.start) {
            return true
        }

        let streak = TrainingStats.currentStreakDays(
            sessionDates: dates, calendar: calendar, now: now
        )
        guard streak > 0 else { return false }
        let today = calendar.startOfDay(for: now)
        let trainedToday = dates.contains { calendar.startOfDay(for: $0) == today }
        guard let anchor = trainedToday
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today),
            let earliestStreakDay = calendar.date(
                byAdding: .day, value: -(streak - 1), to: anchor
            )
        else { return false }
        return oldestDay >= earliestStreakDay
    }
}
