import XCTest
@testable import PickleballTrainingGenie

final class SkillLevelTests: XCTestCase {
    func testScaleIsAscendingAndStartsBelowThree() {
        let values = SkillLevel.allCases.map(\.value)
        XCTAssertEqual(values, values.sorted())
        XCTAssertEqual(values.first, 2.0)
        XCTAssertEqual(values.last, 5.0)
    }

    func testNearestUsesFloorSemantics() {
        XCTAssertEqual(SkillLevel.nearest(to: 4.2), .advanced)
        XCTAssertEqual(SkillLevel.nearest(to: 3.5), .intermediate)
        XCTAssertEqual(SkillLevel.nearest(to: 2.3), .newToTheGame)
        XCTAssertEqual(SkillLevel.nearest(to: 1.0), .newToTheGame)
        XCTAssertEqual(SkillLevel.nearest(to: 6.0), .pro)
    }

    func testNextUpStopsAtPro() {
        XCTAssertEqual(SkillLevel.beginner.nextUp, .intermediate)
        XCTAssertEqual(SkillLevel.pro.nextUp, .pro)
    }

    func testLabels() {
        XCTAssertEqual(SkillLevel.newToTheGame.shortLabel, "2.0")
        XCTAssertEqual(SkillLevel.intermediate.pickerLabel, "3.5 – Intermediate")
    }
}
