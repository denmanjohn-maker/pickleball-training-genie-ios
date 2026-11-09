import XCTest
@testable import PickleballTrainingGenie

@MainActor
final class TodayNavigationTests: XCTestCase {
    private var scope = "today-test-\(UUID().uuidString)"

    override func tearDown() {
        StubURLProtocol.handler = nil
        ControlledURLProtocol.onRequest = nil
        for prefix in ["currentWorkout", "recommendations", "trainingActivity"] {
            OfflineCache.remove(key: "\(prefix)-\(scope)")
        }
        for company in TrainingCompany.allCases {
            OfflineCache.remove(key: "recommendations-\(scope)-players\(company.rawValue)")
        }
        super.tearDown()
    }

    private func client(session: URLSession = StubURLProtocol.makeSession()) -> PickleballTrainingGenieClient {
        let client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: session)
        client.jwtToken = "test-token"
        return client
    }

    private func history(_ dates: [Date]) throws -> Data {
        let formatter = ISO8601DateFormatter()
        let sessions = dates.map {
            Fixtures.session(completedAt: formatter.string(from: $0), drills: [])
        }
        return try JSONEncoder().encode(WorkoutSessionListResponse(
            items: sessions, totalCount: sessions.count, page: 1, pageSize: 50
        ))
    }

    func testSelectionOrderAndMigration() {
        XCTAssertEqual(AppSection.allCases.map(\.title), ["Today", "Train", "Drills", "Progress", "Profile"])
        for raw in ["", "forYou", "tournaments", "unknown"] {
            XCTAssertEqual(AppSection.restored(from: raw), .today)
        }
        for section in AppSection.allCases {
            XCTAssertEqual(AppSection.restored(from: section.rawValue), section)
        }
        XCTAssertEqual(AppSection.restored(from: "workout").title, "Train")
    }

    func testWorkoutActionReviewsCachedTextPlanWithoutChangingIt() {
        let plan = WorkoutPlanResponse(
            warmup: nil, drills: [], cooldown: nil, totalDurationMinutes: nil, rawResponse: "Practice soft dinks."
        )
        OfflineCache.save(plan, key: "currentWorkout-\(scope)")
        let model = DrillsViewModel(client: client(), userId: scope)
        XCTAssertEqual(model.workoutActionTitle, "Review Saved Workout")
        XCTAssertEqual(model.workout?.rawResponse, "Practice soft dinks.")
        XCTAssertNotNil(model.cachedWorkoutDate)
        XCTAssertFalse(model.isGeneratingWorkout)
        XCTAssertFalse(model.isCompletingWorkout)
        XCTAssertFalse(model.workoutCompletedSuccessfully)
        let other = DrillsViewModel(client: client(), userId: "\(scope)-other")
        XCTAssertNil(other.workout)
        XCTAssertEqual(other.workoutActionTitle, "Set Up a Workout")
    }

    func testUnavailableHistoryIsNotZeroHistory() async {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let store = TrainingStreakStore(client: client(), userId: scope)
        await store.load()
        XCTAssertFalse(store.hasHistory)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertNil(store.cachedDate)
        XCTAssertFalse(store.isLoading)
    }

    func testSuccessfulEmptyHistoryIsKnownEmpty() async throws {
        let data = try history([])
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 200), data)
        }
        let store = TrainingStreakStore(client: client(), userId: scope)
        await store.load()
        XCTAssertTrue(store.hasHistory)
        XCTAssertEqual(store.sessionsThisWeek, 0)
        XCTAssertNil(store.errorMessage)
        XCTAssertNil(store.cachedDate)
    }

    func testFailedRefreshLabelsLastSuccessStale() async throws {
        let now = Date()
        let data = try history([now])
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 200), data)
        }
        let store = TrainingStreakStore(client: client(), userId: scope, now: { now })
        await store.load()
        XCTAssertEqual(store.sessionsThisWeek, 1)
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await store.load()
        XCTAssertTrue(store.hasHistory)
        XCTAssertEqual(store.cachedDate, now)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.sessionsThisWeek, 1)
    }

    func testActivityCacheIsIsolatedByAccount() async {
        let date = Date()
        OfflineCache.save([date], key: "trainingActivity-\(scope)")
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let first = TrainingStreakStore(client: client(), userId: scope)
        let other = TrainingStreakStore(client: client(), userId: "\(scope)-other")
        await first.load()
        await other.load()
        XCTAssertTrue(first.hasHistory)
        XCTAssertNotNil(first.cachedDate)
        XCTAssertFalse(other.hasHistory)
        XCTAssertTrue(other.sessionDates.isEmpty)
    }

    func testCalendarBoundaryRecomputesCachedStatsAndRefreshes() async {
        let date = Fixtures.date(2026, 10, 5)
        var now = date
        OfflineCache.save([date], key: "trainingActivity-\(scope)")
        let store = TrainingStreakStore(client: client(), userId: scope, now: { now })
        XCTAssertEqual(store.streakDays, 1)
        var requests = 0
        StubURLProtocol.handler = { _ in
            requests += 1
            throw URLError(.notConnectedToInternet)
        }
        await store.refreshForCalendarChange()
        XCTAssertEqual(requests, 0)
        now = date.addingTimeInterval(3 * 86400)
        await store.refreshForCalendarChange()
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(store.streakDays, 0)
        XCTAssertNotNil(store.cachedDate)
    }

    func testMalformedActivityDoesNotBecomeKnownHistory() async throws {
        let response = WorkoutSessionListResponse(
            items: [Fixtures.session(completedAt: "not-a-date", drills: [])],
            totalCount: 1, page: 1, pageSize: 50
        )
        let data = try JSONEncoder().encode(response)
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 200), data)
        }
        let store = TrainingStreakStore(client: client(), userId: scope)
        await store.load()
        XCTAssertFalse(store.hasHistory)
        XCTAssertNotNil(store.errorMessage)
    }

    func testActivityPagesUntilStatsAreProvenComplete() async throws {
        let now = Date()
        let recent = Fixtures.session(completedAt: ISO8601DateFormatter().string(from: now), drills: [])
        let older = Fixtures.session(
            completedAt: ISO8601DateFormatter().string(from: now.addingTimeInterval(-40 * 86400)), drills: []
        )
        var pages: [String] = []
        StubURLProtocol.handler = { request in
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
                .queryItems!.first { $0.name == "page" }!.value!
            pages.append(page)
            let result = WorkoutSessionListResponse(
                items: [page == "1" ? recent : older], totalCount: 2,
                page: page == "1" ? 1 : 2, pageSize: 50
            )
            return (StubURLProtocol.response(for: request, status: 200), try JSONEncoder().encode(result))
        }
        let store = TrainingStreakStore(client: client(), userId: scope, now: { now })
        await store.load()
        XCTAssertEqual(pages, ["1", "2"])
        XCTAssertTrue(store.hasHistory)
        XCTAssertEqual(store.streakDays, 1)
        XCTAssertEqual(store.sessionsThisWeek, 1)
    }

    func testRunawayPaginationRetainsCacheInsteadOfReportingPartialCounts() async throws {
        OfflineCache.save([Date()], key: "trainingActivity-\(scope)")
        let recent = Fixtures.session(completedAt: ISO8601DateFormatter().string(from: Date()), drills: [])
        let data = try JSONEncoder().encode(WorkoutSessionListResponse(
            items: [recent], totalCount: 100, page: 1, pageSize: 50
        ))
        var requests = 0
        StubURLProtocol.handler = { request in
            requests += 1
            return (StubURLProtocol.response(for: request, status: 200), data)
        }
        let store = TrainingStreakStore(client: client(), userId: scope)
        await store.load()
        XCTAssertEqual(requests, 10)
        XCTAssertEqual(store.sessionDates.count, 1)
        XCTAssertNotNil(store.cachedDate)
        XCTAssertNotNil(store.errorMessage)
    }

    func testWeeklyGoalDoesNotChangeReminderPreferences() {
        let oldGoal = TrainingStats.weeklyGoal
        let enabled = TrainingReminders.isEnabled
        let days = TrainingReminders.savedWeekdays
        let time = TrainingReminders.savedTime
        defer { TrainingStats.weeklyGoal = oldGoal }
        TrainingStats.weeklyGoal = 5
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "training.weeklyGoal"), 5)
        XCTAssertEqual(TrainingReminders.isEnabled, enabled)
        XCTAssertEqual(TrainingReminders.savedWeekdays, days)
        XCTAssertEqual(TrainingReminders.savedTime.hour, time.hour)
        XCTAssertEqual(TrainingReminders.savedTime.minute, time.minute)
    }

    func testRecommendationsCacheAndAccountIsolation() async throws {
        // An entry under the pre-training-company key can't be trusted for
        // any choice, so the view model drops it on init.
        OfflineCache.save([Fixtures.drill(id: "legacy")], key: "recommendations-\(scope)")
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let first = DrillsViewModel(client: client(), userId: scope)
        let other = DrillsViewModel(client: client(), userId: "\(scope)-other")
        XCTAssertNil(OfflineCache.load([Drill].self, key: "recommendations-\(scope)"))

        // The live cache is scoped by user and by the training company in use.
        let drills = [Fixtures.drill(id: "saved")]
        OfflineCache.save(drills, key: "recommendations-\(scope)-players\(first.trainingCompany.rawValue)")
        await first.loadRecommendations()
        await other.loadRecommendations()
        XCTAssertEqual(first.recommendations.map(\.id), ["saved"])
        XCTAssertNotNil(first.cachedRecommendationsDate)
        XCTAssertNil(first.recommendationsError)
        XCTAssertTrue(other.recommendations.isEmpty)
        XCTAssertNotNil(other.recommendationsError)
        XCTAssertNil(other.cachedRecommendationsDate)
    }

    func testServerRecommendationFailureKeepsVisibleDataStaleAndError() async throws {
        let data = try JSONEncoder().encode([Fixtures.drill(id: "fetched")])
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 200), data)
        }
        let model = DrillsViewModel(client: client(), userId: scope)
        await model.loadRecommendations()
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 500), Data("{\"message\":\"Try later\"}".utf8))
        }
        await model.loadRecommendations()
        XCTAssertEqual(model.recommendations.map(\.id), ["fetched"])
        XCTAssertNotNil(model.cachedRecommendationsDate)
        XCTAssertEqual(model.recommendationsError, "Try later")
    }

    func testOverlappingSaveQueuesOneRefreshWithoutDuplicatingActiveFetch() async throws {
        let session = ControlledURLProtocol.makeSession()
        let client = client(session: session)
        let store = TrainingStreakStore(client: client, userId: scope)
        let model = DrillsViewModel(client: client, userId: scope, trainingStreakStore: store)
        let plan = Fixtures.workout(drills: [Fixtures.workoutItem(title: "Dinks")])
        model.workout = plan
        OfflineCache.save(plan, key: "currentWorkout-\(scope)")
        let firstRequested = expectation(description: "First history request held")
        let beforeSave = try history([])
        let afterSave = try history([Date()])
        let savedSession = try JSONEncoder().encode(Fixtures.session(completedAt: "2026-11-07T12:00:00Z", drills: []))
        var held: ControlledURLProtocol?
        var getCount = 0
        ControlledURLProtocol.onRequest = { request, connection in
            if request.httpMethod == "POST" {
                connection.respond(data: savedSession)
            } else {
                getCount += 1
                if getCount == 1 {
                    held = connection
                    firstRequested.fulfill()
                } else {
                    connection.respond(data: afterSave)
                }
            }
        }
        let load = Task { await store.load() }
        await fulfillment(of: [firstRequested], timeout: 3)
        await store.load()
        XCTAssertEqual(getCount, 1)
        await model.completeWorkout(completedIndices: [0])
        XCTAssertTrue(model.workoutCompletedSuccessfully)
        XCTAssertNil(model.workout)
        XCTAssertNil(OfflineCache.load(WorkoutPlanResponse.self, key: "currentWorkout-\(scope)"))
        await store.load(afterSave: true)
        await store.load(afterSave: true)
        held?.respond(data: beforeSave)
        await load.value
        XCTAssertEqual(getCount, 2)
        XCTAssertEqual(store.sessionsThisWeek, 1)
        XCTAssertFalse(store.isLoading)
    }

    func testFailedSaveRetainsPlanAndRetryDoesRefresh() async throws {
        let client = client()
        let store = TrainingStreakStore(client: client, userId: scope)
        let model = DrillsViewModel(client: client, userId: scope, trainingStreakStore: store)
        let plan = Fixtures.workout(drills: [Fixtures.workoutItem(title: "Dinks")])
        model.workout = plan
        model.workoutCompletedSuccessfully = true
        OfflineCache.save(plan, key: "currentWorkout-\(scope)")
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        await model.completeWorkout(completedIndices: [0])
        XCTAssertNotNil(model.workout)
        XCTAssertNotNil(model.workoutError)
        XCTAssertFalse(model.workoutCompletedSuccessfully)
        XCTAssertFalse(store.hasHistory)
        XCTAssertNotNil(OfflineCache.load(WorkoutPlanResponse.self, key: "currentWorkout-\(scope)"))
        let data = try history([Date()])
        let saved = try JSONEncoder().encode(Fixtures.session(completedAt: "2026-11-07T12:00:00Z", drills: []))
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 200), request.httpMethod == "POST" ? saved : data)
        }
        await model.completeWorkout(completedIndices: [0], ratings: [0: 4], notes: "Good practice")
        for _ in 0..<100 where !store.hasHistory {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNil(model.workoutError)
        XCTAssertTrue(model.workoutCompletedSuccessfully)
        XCTAssertEqual(store.sessionsThisWeek, 1)
    }

    func testSavedWorkoutRemainsSuccessfulWhenProgressRefreshFails() async throws {
        let client = client()
        OfflineCache.save([Date()], key: "trainingActivity-\(scope)")
        let store = TrainingStreakStore(client: client, userId: scope)
        let model = DrillsViewModel(client: client, userId: scope, trainingStreakStore: store)
        model.workout = Fixtures.workout(drills: [Fixtures.workoutItem(title: "Dinks")])
        let saved = try JSONEncoder().encode(Fixtures.session(completedAt: "2026-11-07T12:00:00Z", drills: []))
        StubURLProtocol.handler = { request in
            guard request.httpMethod == "POST" else { throw URLError(.notConnectedToInternet) }
            return (StubURLProtocol.response(for: request, status: 200), saved)
        }
        await model.completeWorkout(completedIndices: [0])
        for _ in 0..<100 where store.errorMessage == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(model.workoutCompletedSuccessfully)
        XCTAssertNil(model.workout)
        XCTAssertNil(model.workoutError)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertNotNil(store.cachedDate)
    }

    func testSaveReturnsBeforeNewHistoryRefreshFinishes() async throws {
        let client = client(session: ControlledURLProtocol.makeSession())
        let store = TrainingStreakStore(client: client, userId: scope)
        let model = DrillsViewModel(client: client, userId: scope, trainingStreakStore: store)
        model.workout = Fixtures.workout(drills: [Fixtures.workoutItem(title: "Dinks")])
        let saved = try JSONEncoder().encode(Fixtures.session(completedAt: "2026-11-07T12:00:00Z", drills: []))
        let requested = expectation(description: "Post-save GET held")
        var held: ControlledURLProtocol?
        ControlledURLProtocol.onRequest = { request, connection in
            if request.httpMethod == "POST" {
                connection.respond(data: saved)
            } else {
                held = connection
                requested.fulfill()
            }
        }
        await model.completeWorkout(completedIndices: [0])
        XCTAssertFalse(model.isCompletingWorkout)
        XCTAssertTrue(model.workoutCompletedSuccessfully)
        await fulfillment(of: [requested], timeout: 3)
        XCTAssertTrue(store.isLoading)
        XCTAssertFalse(model.isCompletingWorkout)
        held?.respond(data: try history([]))
        for _ in 0..<100 where store.isLoading {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(store.isLoading)
    }
}

/// Allows one history request to remain in flight while a save completes.
private final class ControlledURLProtocol: URLProtocol {
    static var onRequest: ((URLRequest, ControlledURLProtocol) -> Void)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.onRequest?(request, self) }
    override func stopLoading() {}

    func respond(data: Data) {
        client?.urlProtocol(self, didReceive: StubURLProtocol.response(for: request, status: 200), cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ControlledURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
