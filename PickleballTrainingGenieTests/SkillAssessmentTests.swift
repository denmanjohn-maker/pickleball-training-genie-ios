import XCTest
@testable import PickleballTrainingGenie

final class SkillAssessmentTests: XCTestCase {
    private func answers(_ answer: AssessmentQuestion.Answer) -> [Int: AssessmentQuestion.Answer] {
        Dictionary(uniqueKeysWithValues: SkillAssessment.questions.map { ($0.id, answer) })
    }

    func testAllNoIsNewToTheGame() {
        let result = SkillAssessment.score(answers: answers(.no))
        XCTAssertEqual(result.estimatedLevel, 2.0)
        XCTAssertEqual(result.estimatedSkillLevel, .newToTheGame)
    }

    func testAllYesCapsAtFourPointZero() {
        let result = SkillAssessment.score(answers: answers(.yes))
        XCTAssertEqual(result.estimatedLevel, 4.0)
        XCTAssertEqual(result.suggestedRatings.target, 5.0)
    }

    func testAllSometimesLandsMidScale() {
        XCTAssertEqual(SkillAssessment.score(answers: answers(.sometimes)).estimatedLevel, 3.0)
    }

    func testCategoryStrengthsAndFocus() {
        var mixed = answers(.yes)
        // Fail the dinking question (id 5) and the resets question (id 8).
        mixed[5] = .no
        mixed[8] = .no
        let result = SkillAssessment.score(answers: mixed)
        XCTAssertEqual(result.categoryStrengths["Dinking"], 0)
        XCTAssertEqual(result.categoryStrengths["Resets"], 0)
        XCTAssertEqual(result.categoryStrengths["Serving"], 1)
        XCTAssertEqual(Set(result.focusCategories), ["Dinking", "Resets"])
    }

    func testUnansweredQuestionsAreIgnored() {
        let result = SkillAssessment.score(answers: [1: .yes])
        XCTAssertEqual(result.categoryStrengths.keys.sorted(), ["Serving"])
        XCTAssertEqual(result.estimatedLevel, 4.0)
    }

    func testRankPutsWeakCategoriesFirstAndIsStable() {
        let result = AssessmentResult(
            estimatedLevel: 3.0,
            categoryStrengths: ["Dinking": 0.2, "Serving": 1.0],
            completedAt: Date()
        )
        let drills = [
            Fixtures.drill(id: "serve", category: "Serving"),
            Fixtures.drill(id: "lob", category: "Lobs"),        // no signal → 0.75
            Fixtures.drill(id: "dink1", category: "Dinking"),
            Fixtures.drill(id: "dink2", category: "Dinking")
        ]
        let ranked = SkillAssessment.rank(drills, by: result).map(\.id)
        XCTAssertEqual(ranked, ["dink1", "dink2", "lob", "serve"])
    }

    func testResultRoundTripsThroughJSON() throws {
        let original = AssessmentResult(estimatedLevel: 2.5, categoryStrengths: ["Volleys": 0.5], completedAt: Fixtures.date(2026, 1, 2))
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(AssessmentResult.self, from: data), original)
    }
}
