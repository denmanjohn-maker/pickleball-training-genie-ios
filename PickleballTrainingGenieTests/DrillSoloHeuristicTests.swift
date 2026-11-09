import XCTest
@testable import PickleballTrainingGenie

final class DrillSoloHeuristicTests: XCTestCase {
    private func solo(_ title: String, _ description: String, category: String = "Dinking") -> Bool {
        DrillSoloHeuristic.isSoloFriendly(title: title, description: description, category: category)
    }

    func testWallAndBallMachineDrillsAreSolo() {
        XCTAssertTrue(solo("Wall Dinks", "Dink against a wall for two minutes."))
        XCTAssertTrue(solo("Machine Volleys", "Set the ball machine to feed at the kitchen line."))
        XCTAssertTrue(solo("Self-Feed Drops", "Drop the ball and hit a third-shot drop into the kitchen."))
    }

    func testPartnerDrillsAreNot() {
        XCTAssertFalse(solo("Cross-Court Dinks", "Have your partner dink cross-court while you reset."))
        XCTAssertFalse(solo("Blocks", "A feeder drives balls at you from the baseline."))
        XCTAssertFalse(solo("Wall Ball Game", "Two players alternate hitting against the wall."))
    }

    func testNegatedPartnerMentionCountsAsSolo() {
        XCTAssertTrue(solo("Shadow Swings", "No partner needed — shadow the motion."))
        XCTAssertTrue(solo("Serve Targets", "Without a partner, aim serves at cones.", category: "Returns"))
    }

    func testServingIsSoloUnlessItSaysOtherwise() {
        XCTAssertTrue(solo("Deep Serves", "Hit twenty serves past the midline.", category: "Serving"))
        XCTAssertFalse(solo("Serve and Return", "Serve while your partner returns deep.", category: "Serving"))
    }

    func testPlainPartnerlessDescriptionWithoutSoloCueIsNotAssumedSolo() {
        XCTAssertFalse(solo("Transition Footwork", "Move from the baseline to the kitchen line between shots."))
    }

    func testDrillConvenience() {
        XCTAssertTrue(Fixtures.drill(title: "Wall Dinks", description: "Against a wall.").isSoloFriendly)
        XCTAssertFalse(Fixtures.drill(description: "Partner feeds.").isSoloFriendly)
    }

    func testServerMinPlayersWinsOverKeywords() {
        // Text screams "partner", but the server says solo (e.g. a wall
        // alternative is described) — the tag is authoritative.
        let taggedSolo = Fixtures.drill(
            description: "With a partner feeding, or off a wall.", minPlayers: 1)
        XCTAssertTrue(taggedSolo.isSoloFriendly)

        // Text looks solo (a wall is mentioned), but the server says partner.
        let taggedPartner = Fixtures.drill(
            description: "Stand near the wall of the court while your feed comes in.", minPlayers: 2)
        XCTAssertFalse(taggedPartner.isSoloFriendly)

        let taggedGroup = Fixtures.drill(description: "Solo warm-up before the pattern.", minPlayers: 4)
        XCTAssertFalse(taggedGroup.isSoloFriendly)
    }

    func testHeuristicStillAppliesWhenServerTagIsMissing() {
        let untagged = Fixtures.drill(description: "Hit against a wall for 10 minutes.", minPlayers: nil)
        XCTAssertTrue(untagged.isSoloFriendly)
    }
}
