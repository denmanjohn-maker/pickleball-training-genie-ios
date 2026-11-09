import XCTest
@testable import PickleballTrainingGenie

@MainActor
final class DrillsViewModelTests: XCTestCase {
    private func makeViewModel() -> DrillsViewModel {
        let client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
        let viewModel = DrillsViewModel(client: client, userId: "test-\(UUID().uuidString)")
        viewModel.drills = [
            Fixtures.drill(id: "a", level: 3.0, category: "Dinking"),
            Fixtures.drill(id: "b", level: 3.5, category: "Dinking"),
            Fixtures.drill(id: "c", level: 4.0, category: "Serving")
        ]
        return viewModel
    }

    func testNoFilterShowsEverything() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.filteredDrills.map(\.id), ["a", "b", "c"])
        XCTAssertNil(viewModel.levelFallbackNotice)
    }

    func testExactLevelMatch() {
        let viewModel = makeViewModel()
        viewModel.selectedLevel = 3.5
        XCTAssertEqual(viewModel.filteredDrills.map(\.id), ["b"])
        XCTAssertNil(viewModel.levelFallbackNotice)
    }

    func testBeginnerLevelFallsBackToNearestPopulatedLevel() {
        let viewModel = makeViewModel()
        viewModel.selectedLevel = 2.0
        XCTAssertEqual(viewModel.filteredDrills.map(\.id), ["a"])
        XCTAssertEqual(viewModel.levelFallbackNotice?.requested, 2.0)
        XCTAssertEqual(viewModel.levelFallbackNotice?.showing, 3.0)
    }

    func testFallbackTiePrefersEasierLevel() {
        let viewModel = makeViewModel()
        viewModel.drills = [
            Fixtures.drill(id: "low", level: 3.0),
            Fixtures.drill(id: "high", level: 4.0)
        ]
        viewModel.selectedLevel = 3.5
        XCTAssertEqual(viewModel.filteredDrills.map(\.id), ["low"])
        XCTAssertEqual(viewModel.levelFallbackNotice?.showing, 3.0)
    }

    func testCategoryFilterCombinesWithLevelFallback() {
        let viewModel = makeViewModel()
        viewModel.selectedCategory = "Serving"
        viewModel.selectedLevel = 2.5
        XCTAssertEqual(viewModel.filteredDrills.map(\.id), ["c"])
        XCTAssertEqual(viewModel.levelFallbackNotice?.showing, 4.0)
    }

    func testEmptyLibraryHasNoFallback() {
        let viewModel = makeViewModel()
        viewModel.drills = []
        viewModel.selectedLevel = 3.0
        XCTAssertTrue(viewModel.filteredDrills.isEmpty)
        XCTAssertNil(viewModel.levelFallbackNotice)
    }

    // MARK: - Training company

    private func isolatedDefaults() -> UserDefaults {
        let suite = "DrillsViewModelTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testTrainingCompanyDefaultsToSolo() {
        let client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
        let viewModel = DrillsViewModel(client: client, userId: "t", defaults: isolatedDefaults())
        XCTAssertEqual(viewModel.trainingCompany, .solo)
    }

    func testTrainingCompanyPersistsAcrossViewModels() {
        let client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
        let defaults = isolatedDefaults()

        let first = DrillsViewModel(client: client, userId: "t", defaults: defaults)
        first.trainingCompany = .group

        let second = DrillsViewModel(client: client, userId: "t", defaults: defaults)
        XCTAssertEqual(second.trainingCompany, .group)
        XCTAssertEqual(defaults.integer(forKey: TrainingCompany.storageKey), 4)
    }

    func testTrainingCompanyIgnoresCorruptStoredValue() {
        let client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
        let defaults = isolatedDefaults()
        defaults.set(3, forKey: TrainingCompany.storageKey)

        let viewModel = DrillsViewModel(client: client, userId: "t", defaults: defaults)
        XCTAssertEqual(viewModel.trainingCompany, .solo)
    }

    func testGenerateWorkoutSendsTrainingCompany() async {
        let client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
        client.jwtToken = "abc"
        let viewModel = DrillsViewModel(client: client, userId: "t", defaults: isolatedDefaults())
        viewModel.trainingCompany = .partner
        viewModel.workoutDuration = 45

        var body: [String: Any] = [:]
        StubURLProtocol.handler = { request in
            if let data = request.bodyData(),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                body = json
            }
            return (StubURLProtocol.response(for: request, status: 200), Data(#"{"drills":[]}"#.utf8))
        }
        defer { StubURLProtocol.handler = nil }

        await viewModel.generateWorkout()

        XCTAssertEqual(body["durationMinutes"] as? Int, 45)
        XCTAssertEqual(body["playersAvailable"] as? Int, 2)
        XCTAssertNil(viewModel.workoutError)
    }

    // MARK: - Recommendations follow the training company

    private static let partnerDrillJSON = Data(#"""
    [{"id":"partner-dinks","title":"Partner Dinks","description":"Dink cross-court with a partner.",
      "targetDUPRLevel":3.0,"category":"Dinking","sourceUrl":"https://example.test/drill",
      "createdAt":"2026-01-01T00:00:00Z","minPlayers":2}]
    """#.utf8)

    private func makeAuthenticatedViewModel() -> DrillsViewModel {
        let client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
        client.jwtToken = "abc"
        return DrillsViewModel(client: client, userId: "t-\(UUID().uuidString)", defaults: isolatedDefaults())
    }

    func testChangingTrainingCompanyClearsLoadedRecommendations() {
        let viewModel = makeAuthenticatedViewModel()
        viewModel.trainingCompany = .partner
        viewModel.recommendations = [Fixtures.drill(id: "p", minPlayers: 2)]
        viewModel.cachedRecommendationsDate = Date()

        viewModel.trainingCompany = .partner
        XCTAssertEqual(viewModel.recommendations.map(\.id), ["p"], "Re-selecting the same choice keeps what is loaded")

        viewModel.trainingCompany = .solo
        XCTAssertTrue(viewModel.recommendations.isEmpty)
        XCTAssertNil(viewModel.cachedRecommendationsDate)
        XCTAssertNil(viewModel.recommendationsError)
    }

    func testRecommendationsForThePreviousChoiceAreDiscardedWhenTheyArrive() async {
        let viewModel = makeAuthenticatedViewModel()
        viewModel.trainingCompany = .partner
        let gate = DispatchSemaphore(value: 0)
        StubURLProtocol.handler = { request in
            gate.wait()
            return (StubURLProtocol.response(for: request, status: 200), Self.partnerDrillJSON)
        }
        defer { StubURLProtocol.handler = nil }

        let inFlight = Task { await viewModel.loadRecommendations() }
        while !viewModel.isLoadingRecommendations { await Task.yield() }

        viewModel.trainingCompany = .solo
        gate.signal()
        await inFlight.value

        XCTAssertTrue(viewModel.recommendations.isEmpty, "A partner reply must not fill a solo session")
        XCTAssertFalse(viewModel.isLoadingRecommendations)
    }

    func testRecommendationCacheIsScopedToTrainingCompany() async {
        let viewModel = makeAuthenticatedViewModel()
        viewModel.trainingCompany = .partner
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 200), Self.partnerDrillJSON)
        }
        defer { StubURLProtocol.handler = nil }

        await viewModel.loadRecommendations()
        XCTAssertEqual(viewModel.recommendations.map(\.id), ["partner-dinks"])

        // Offline from here on.
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }

        viewModel.trainingCompany = .solo
        await viewModel.loadRecommendations()
        XCTAssertTrue(viewModel.recommendations.isEmpty, "Partner drills must not be restored for a solo session")
        XCTAssertNotNil(viewModel.recommendationsError)

        viewModel.trainingCompany = .partner
        await viewModel.loadRecommendations()
        XCTAssertEqual(viewModel.recommendations.map(\.id), ["partner-dinks"])
        XCTAssertNotNil(viewModel.cachedRecommendationsDate)
    }

    func testGenerateWorkoutSurfacesServerExplanationOn400() async {
        let client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
        client.jwtToken = "abc"
        let viewModel = DrillsViewModel(client: client, userId: "t", defaults: isolatedDefaults())

        StubURLProtocol.handler = { request in
            let message = "No solo drills found for your DUPR range yet. Try 'With a partner'."
            return (StubURLProtocol.response(for: request, status: 400, headers: ["Content-Type": "text/plain"]), Data(message.utf8))
        }
        defer { StubURLProtocol.handler = nil }

        await viewModel.generateWorkout()

        XCTAssertEqual(viewModel.workoutError, "No solo drills found for your DUPR range yet. Try 'With a partner'.")
    }
}
