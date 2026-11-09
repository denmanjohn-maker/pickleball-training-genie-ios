import XCTest
@testable import PickleballTrainingGenie

final class DrillInstructionsTests: XCTestCase {
    func testParsesTheCuratedTemplate() {
        let description = """
        Learn the soft dink stroke against a wall before anyone is across the net from you.

        Setup: Find any solid wall and mark a line at net height.
        How to run it: Dink the ball softly so it hits the wall above your line.
        Goal: 25 controlled dinks in a row.
        Coaching cue: Soft grip, paddle out front.
        """

        let parsed = DrillInstructions.parse(description)

        XCTAssertEqual(parsed.summary, "Learn the soft dink stroke against a wall before anyone is across the net from you.")
        XCTAssertEqual(parsed.setup, "Find any solid wall and mark a line at net height.")
        XCTAssertEqual(parsed.howToRun, "Dink the ball softly so it hits the wall above your line.")
        XCTAssertEqual(parsed.goal, "25 controlled dinks in a row.")
        XCTAssertEqual(parsed.coachingCue, "Soft grip, paddle out front.")
        XCTAssertTrue(parsed.hasSections)
    }

    func testPlainProseStaysASummary() {
        let parsed = DrillInstructions.parse("Stand at the kitchen line and dink with a partner for 50 in a row.")

        XCTAssertEqual(parsed.summary, "Stand at the kitchen line and dink with a partner for 50 in a row.")
        XCTAssertNil(parsed.setup)
        XCTAssertFalse(parsed.hasSections)
    }

    func testWrappedSectionLinesAreJoined_AndEmptySectionsAreNil() {
        let parsed = DrillInstructions.parse("Summary line.\nSetup: First part\nsecond part.\nGoal:\nCoaching cue: Breathe.")

        XCTAssertEqual(parsed.summary, "Summary line.")
        XCTAssertEqual(parsed.setup, "First part second part.")
        XCTAssertNil(parsed.goal)
        XCTAssertEqual(parsed.coachingCue, "Breathe.")
    }

    func testSectionsWithoutSummaryStillParse() {
        let parsed = DrillInstructions.parse("Setup: A wall.\nHow to run it: Dink.")

        XCTAssertEqual(parsed.summary, "")
        XCTAssertEqual(parsed.setup, "A wall.")
        XCTAssertTrue(parsed.hasSections)
    }

    func testEquipmentItemsSplitAndTrim() {
        XCTAssertEqual(DrillInstructions.equipmentItems(from: "Wall, Bucket of balls ,Cones or targets"),
                       ["Wall", "Bucket of balls", "Cones or targets"])
        XCTAssertEqual(DrillInstructions.equipmentItems(from: nil), [])
        XCTAssertEqual(DrillInstructions.equipmentItems(from: " , "), [])
    }

    func testDrillAndWorkoutItemExposeInstructions() {
        let drill = Fixtures.drill(description: "Sum.\n\nSetup: S.\nHow to run it: H.\nGoal: G.\nCoaching cue: C.", equipment: "Wall")
        XCTAssertEqual(drill.instructions.howToRun, "H.")
        XCTAssertEqual(drill.equipmentItems, ["Wall"])

        let tagged = Fixtures.workoutItem(title: "T", description: "Sum.\n\nSetup: S.", minPlayers: 1, equipment: "Ball machine")
        XCTAssertEqual(tagged.instructions?.setup, "S.")
        XCTAssertEqual(tagged.equipmentItems, ["Ball machine"])

        let legacy = Fixtures.workoutItem(title: "L")
        XCTAssertNil(legacy.instructions)
        XCTAssertEqual(legacy.equipmentItems, [])
    }
}
