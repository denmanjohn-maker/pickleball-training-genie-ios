import XCTest
@testable import PickleballTrainingGenie

final class ZipCityMatcherTests: XCTestCase {
    private let cities = [
        City(id: 1, name: "Los Angeles", state: "CA", zip: "90001", events1Month: 0, events3Month: 0),
        City(id: 2, name: "New York", state: "NY", zip: "10001", events1Month: 0, events3Month: 0),
        City(id: 3, name: "Houston", state: "TX", zip: "77001", events1Month: 0, events3Month: 0)
    ]

    func testValidZip() {
        XCTAssertTrue(ZipCityMatcher.isValidZip("90210"))
        XCTAssertFalse(ZipCityMatcher.isValidZip("9021"))
        XCTAssertFalse(ZipCityMatcher.isValidZip("9021O"))
    }

    func testPicksGeographicallyClosestCity() {
        XCTAssertEqual(ZipCityMatcher.closestCity(toZip: "90210", in: cities)?.name, "Los Angeles")
        XCTAssertEqual(ZipCityMatcher.closestCity(toZip: "10016", in: cities)?.name, "New York")
        XCTAssertEqual(ZipCityMatcher.closestCity(toZip: "78701", in: cities)?.name, "Houston") // Austin → Houston
    }

    func testInvalidInputReturnsNil() {
        XCTAssertNil(ZipCityMatcher.closestCity(toZip: "abc", in: cities))
        XCTAssertNil(ZipCityMatcher.closestCity(toZip: "90210", in: []))
    }
}
