import XCTest
@testable import PickleballTrainingGenie

final class OfflineCacheTests: XCTestCase {
    private let key = "test-\(UUID().uuidString)"

    override func tearDown() {
        OfflineCache.remove(key: key)
        super.tearDown()
    }

    func testRoundTripKeepsValueAndTimestamp() {
        let drills = [Fixtures.drill(id: "x"), Fixtures.drill(id: "y", level: 3.5)]
        let before = Date()
        OfflineCache.save(drills, key: key)
        let entry = OfflineCache.load([Drill].self, key: key)
        XCTAssertEqual(entry?.value, drills)
        XCTAssertGreaterThanOrEqual(entry?.savedAt ?? .distantPast, before.addingTimeInterval(-1))
    }

    func testMissingKeyIsNil() {
        XCTAssertNil(OfflineCache.load([Drill].self, key: "never-saved-\(UUID().uuidString)"))
    }

    func testRemoveDeletesEntry() {
        OfflineCache.save(["a"], key: key)
        OfflineCache.remove(key: key)
        XCTAssertNil(OfflineCache.load([String].self, key: key))
    }

    func testTypeMismatchIsNilNotCrash() {
        OfflineCache.save(["a", "b"], key: key)
        XCTAssertNil(OfflineCache.load([Drill].self, key: key))
    }
}
