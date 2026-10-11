import Foundation
import XCTest
@testable import PickleballTrainingGenie

/// Intercepts every request on a stub `URLSession` so client tests run with no
/// network. Set `handler` per test; it receives the outgoing request and
/// returns the response to deliver.
final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func response(for request: URLRequest, status: Int, headers: [String: String] = ["Content-Type": "application/json"]) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
    }
}

enum Fixtures {
    static let baseURL = URL(string: "https://example.test/")!

    static func drill(
        id: String = UUID().uuidString,
        title: String = "Dink Rally",
        description: String = "Keep a cross-court dink rally going.",
        level: Decimal = 3.0,
        category: String = "Dinking"
    ) -> Drill {
        Drill(
            id: id,
            title: title,
            description: description,
            targetDUPRLevel: level,
            category: category,
            videoUrl: nil,
            sourceUrl: "https://example.test/drill",
            createdAt: "2026-01-01T00:00:00Z"
        )
    }

    static func workoutItem(title: String, category: String = "Dinking", minutes: Int = 5) -> WorkoutDrillItem {
        WorkoutDrillItem(title: title, category: category, durationMinutes: minutes, coachingNotes: "Stay low.")
    }

    static func workout(
        warmup: String? = "Jog and shadow swings.",
        drills: [WorkoutDrillItem],
        cooldown: String? = "Stretch."
    ) -> WorkoutPlanResponse {
        WorkoutPlanResponse(
            warmup: warmup,
            drills: drills,
            cooldown: cooldown,
            totalDurationMinutes: drills.reduce(0) { $0 + $1.durationMinutes },
            rawResponse: nil
        )
    }

    static func session(
        id: String = UUID().uuidString,
        completedAt: String,
        drills: [WorkoutSessionDrillPayload]
    ) -> WorkoutSessionResponse {
        WorkoutSessionResponse(
            id: id,
            completedAt: completedAt,
            durationMinutes: drills.reduce(0) { $0 + $1.durationMinutes },
            warmup: nil,
            cooldown: nil,
            notes: nil,
            drills: drills
        )
    }

    static func sessionDrill(category: String, rating: Int?) -> WorkoutSessionDrillPayload {
        WorkoutSessionDrillPayload(
            title: "\(category) drill",
            category: category,
            durationMinutes: 5,
            coachingNotes: nil,
            isCompleted: true,
            selfRating: rating
        )
    }

    /// A fixed UTC calendar so date math doesn't depend on the test machine.
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday, regardless of the runner's locale
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
