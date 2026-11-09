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
