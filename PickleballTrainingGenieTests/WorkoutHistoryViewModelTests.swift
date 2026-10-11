import XCTest
@testable import PickleballTrainingGenie

@MainActor
final class WorkoutHistoryViewModelTests: XCTestCase {
    private func makeViewModel(sessions: [WorkoutSessionResponse]) -> WorkoutHistoryViewModel {
        let client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
        let viewModel = WorkoutHistoryViewModel(client: client)
        viewModel.sessions = sessions
        return viewModel
    }

    private func session(daysAgo: Int, category: String, rating: Int?) -> WorkoutSessionResponse {
        Fixtures.session(
            completedAt: "2026-08-\(String(format: "%02d", 20 - daysAgo))T10:00:00Z",
            drills: [Fixtures.sessionDrill(category: category, rating: rating)]
        )
    }

    func testNoRatingsNoTrends() {
        let viewModel = makeViewModel(sessions: [session(daysAgo: 0, category: "Dinking", rating: nil)])
        XCTAssertTrue(viewModel.categoryTrends.isEmpty)
    }

    func testRecentOnlyHasNoDirection() {
        let viewModel = makeViewModel(sessions: [
            session(daysAgo: 0, category: "Dinking", rating: 5),
            session(daysAgo: 1, category: "Dinking", rating: 3)
        ])
        let trend = viewModel.categoryTrends.first
        XCTAssertEqual(trend?.category, "Dinking")
        XCTAssertEqual(trend?.recentAverage ?? 0, 4.0, accuracy: 0.001)
        XCTAssertNil(trend?.direction)
    }

    func testImprovementIsUpAndWeakestSortsFirst() {
        // Newest first: five recent sessions, then three older ones to compare against.
        let recent = (0..<5).map { day in
            Fixtures.session(
                completedAt: "2026-08-\(String(format: "%02d", 20 - day))T10:00:00Z",
                drills: [
                    Fixtures.sessionDrill(category: "Dinking", rating: 5),
                    Fixtures.sessionDrill(category: "Serving", rating: 1)
                ]
            )
        }
        let earlier = (5..<8).map { day in
            Fixtures.session(
                completedAt: "2026-08-\(String(format: "%02d", 20 - day))T10:00:00Z",
                drills: [
                    Fixtures.sessionDrill(category: "Dinking", rating: 1),
                    Fixtures.sessionDrill(category: "Serving", rating: 3)
                ]
            )
        }
        let viewModel = makeViewModel(sessions: recent + earlier)
        let trends = viewModel.categoryTrends
        XCTAssertEqual(trends.map(\.category), ["Serving", "Dinking"])
        XCTAssertEqual(trends[0].direction, .down)
        XCTAssertEqual(trends[1].direction, .up)
    }

    func testVolumeStats() {
        let viewModel = makeViewModel(sessions: [
            session(daysAgo: 0, category: "Dinking", rating: nil),
            session(daysAgo: 1, category: "Drops", rating: nil)
        ])
        XCTAssertEqual(viewModel.totalMinutesTrained, 10)
    }
}
