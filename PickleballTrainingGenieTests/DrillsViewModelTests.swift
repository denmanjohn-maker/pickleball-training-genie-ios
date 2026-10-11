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
}
