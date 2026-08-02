import Foundation

// MARK: - Questions

/// One question in the 60-second skill check. Answers contribute `weight`
/// toward the level estimate and a strength signal for `categories`.
struct AssessmentQuestion: Identifiable {
    enum Answer: Int, CaseIterable, Codable {
        case no
        case sometimes
        case yes

        var label: String {
            switch self {
            case .no: return "Not yet"
            case .sometimes: return "Sometimes"
            case .yes: return "Yes"
            }
        }

        /// Score contribution in 0...1.
        var score: Double {
            switch self {
            case .no: return 0
            case .sometimes: return 0.5
            case .yes: return 1
            }
        }
    }

    let id: Int
    let prompt: String
    let detail: String?
    /// Entries from `DrillsViewModel.drillCategories` this question signals.
    let categories: [String]
    /// Harder skills carry more weight toward the level estimate.
    let weight: Double
}

// MARK: - Result

/// Outcome of the skill check. Persisted locally (UserDefaults) — the backend
/// only ever sees the resulting DUPR numbers via the existing profile fields.
struct AssessmentResult: Codable, Equatable {
    /// Stored as Double so the JSON round-trips cleanly (mirrors the
    /// `UpdateProfileRequest` convention for DUPR values).
    let estimatedLevel: Double
    /// Per-category strength in 0...1. Only categories a question touched.
    let categoryStrengths: [String: Double]
    let completedAt: Date

    var estimatedSkillLevel: SkillLevel {
        .nearest(to: Decimal(estimatedLevel))
    }

    /// Weakest categories with signal — what the player should drill first.
    var focusCategories: [String] {
        categoryStrengths
            .filter { $0.value < 0.75 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value }
            .prefix(3)
            .map(\.key)
    }
}

// MARK: - Scoring + persistence

enum SkillAssessment {
    /// Plain-language questions — no jargon a brand-new player wouldn't know,
    /// and any term used (kitchen, dink, third-shot drop) gets a `detail`.
    static let questions: [AssessmentQuestion] = [
        AssessmentQuestion(
            id: 1,
            prompt: "Can you get your serve in play most of the time?",
            detail: nil,
            categories: ["Serving"],
            weight: 1.0
        ),
        AssessmentQuestion(
            id: 2,
            prompt: "Can you return a serve deep into the court on purpose?",
            detail: "Landing your return near the baseline, not just getting it back.",
            categories: ["Returns"],
            weight: 1.0
        ),
        AssessmentQuestion(
            id: 3,
            prompt: "Do you know the kitchen rule?",
            detail: "The non-volley zone — when you can and can't stand in it.",
            categories: ["General"],
            weight: 1.0
        ),
        AssessmentQuestion(
            id: 4,
            prompt: "Can you keep score confidently without help?",
            detail: "Calling all three numbers in doubles, and knowing when sides switch.",
            categories: ["General"],
            weight: 1.0
        ),
        AssessmentQuestion(
            id: 5,
            prompt: "Can you keep a dink rally going for 10 or more shots?",
            detail: "Dinks are soft shots that land in the kitchen.",
            categories: ["Dinking"],
            weight: 1.5
        ),
        AssessmentQuestion(
            id: 6,
            prompt: "Do you use a third-shot drop to get to the net?",
            detail: "A soft shot from the baseline that lands in the kitchen so you can move up.",
            categories: ["Drops"],
            weight: 1.5
        ),
        AssessmentQuestion(
            id: 7,
            prompt: "Can you volley at the kitchen line without popping the ball up?",
            detail: "Hitting the ball out of the air with control, keeping it low.",
            categories: ["Volleys"],
            weight: 1.5
        ),
        AssessmentQuestion(
            id: 8,
            prompt: "When a ball is hit hard at you, can you block or reset it softly?",
            detail: "Absorbing the pace so the ball drops gently into the kitchen.",
            categories: ["Resets"],
            weight: 2.0
        ),
        AssessmentQuestion(
            id: 9,
            prompt: "Do you move up toward the kitchen line after your return?",
            detail: nil,
            categories: ["Movement"],
            weight: 1.0
        ),
        AssessmentQuestion(
            id: 10,
            prompt: "Do you win points on purpose with speed-ups or putaways?",
            detail: "Choosing the right ball to attack, not just swinging hard.",
            categories: ["Attacking"],
            weight: 2.0
        )
    ]

    /// Maps a weighted score fraction (0...1) onto the level scale. The
    /// self-check deliberately caps at 4.0 — 5.0 is earned in tournaments,
    /// not claimed in a questionnaire.
    static func score(answers: [Int: AssessmentQuestion.Answer]) -> AssessmentResult {
        var earned = 0.0
        var possible = 0.0
        var categoryTotals: [String: (earned: Double, possible: Double)] = [:]

        for question in questions {
            guard let answer = answers[question.id] else { continue }
            earned += answer.score * question.weight
            possible += question.weight
            for category in question.categories {
                var totals = categoryTotals[category] ?? (0, 0)
                totals.earned += answer.score
                totals.possible += 1
                categoryTotals[category] = totals
            }
        }

        let fraction = possible > 0 ? earned / possible : 0
        let level: Double
        switch fraction {
        case ..<0.15: level = 2.0
        case ..<0.35: level = 2.5
        case ..<0.55: level = 3.0
        case ..<0.75: level = 3.5
        default: level = 4.0
        }

        let strengths = categoryTotals.mapValues { $0.possible > 0 ? $0.earned / $0.possible : 0 }
        return AssessmentResult(
            estimatedLevel: level,
            categoryStrengths: strengths,
            completedAt: Date()
        )
    }

    // MARK: Persistence (local-only, like `tournaments.lastCityId`)

    private static let defaultsKey = "assessment.result"

    static func save(_ result: AssessmentResult) {
        if let data = try? JSONEncoder().encode(result) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    static func load() -> AssessmentResult? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(AssessmentResult.self, from: data)
    }

    /// Stable re-rank surfacing drills for the player's weakest categories
    /// first. Categories the check has no signal for stay in the middle.
    static func rank(_ drills: [Drill], by result: AssessmentResult) -> [Drill] {
        drills.enumerated()
            .sorted { a, b in
                let strengthA = result.categoryStrengths[a.element.category] ?? 0.75
                let strengthB = result.categoryStrengths[b.element.category] ?? 0.75
                return strengthA == strengthB ? a.offset < b.offset : strengthA < strengthB
            }
            .map(\.element)
    }
}
