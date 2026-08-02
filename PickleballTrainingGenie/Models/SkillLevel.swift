import SwiftUI

/// Single source of truth for the skill-level scale used across the app —
/// pickers, filter chips, badges, and the About card all read from this.
///
/// The scale intentionally extends below DUPR's traditional 3.0 floor: the app
/// serves players who can't access coaching, and most of them sit at 2.0–2.5.
/// A backend that predates the sub-3.0 tiers simply has no drills tagged
/// there; `DrillsViewModel` falls back to the nearest populated level so those
/// players never see an empty screen.
enum SkillLevel: CaseIterable, Identifiable {
    case newToTheGame     // 2.0
    case advancedBeginner // 2.5
    case beginner         // 3.0
    case intermediate     // 3.5
    case advanced         // 4.0
    case pro              // 5.0

    var id: Decimal { value }

    /// The DUPR value sent to and received from the backend.
    var value: Decimal {
        switch self {
        case .newToTheGame: return 2.0
        case .advancedBeginner: return 2.5
        case .beginner: return 3.0
        case .intermediate: return 3.5
        case .advanced: return 4.0
        case .pro: return 5.0
        }
    }

    /// Plain-language name, shown ahead of the DUPR number — "3.0 is a
    /// beginner" means nothing to someone who just bought a paddle.
    var name: String {
        switch self {
        case .newToTheGame: return "New to the Game"
        case .advancedBeginner: return "Advanced Beginner"
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .pro: return "Pro"
        }
    }

    /// One-line description used in pickers and the About DUPR card.
    var summary: String {
        switch self {
        case .newToTheGame: return "Learning to serve and return, still learning the rules"
        case .advancedBeginner: return "Can sustain short rallies, knows the basic rules"
        case .beginner: return "Learning basic strokes, court positioning"
        case .intermediate: return "Third shot drop, kitchen game, transitions"
        case .advanced: return "Pattern recognition, speed-up/reset sequences"
        case .pro: return "ATP, Erne, tournament-level tactics"
        }
    }

    /// Badge/accent color. 5.0 keeps the filled neon-magenta treatment.
    var color: Color {
        switch self {
        case .newToTheGame: return .green
        case .advancedBeginner: return .mint
        case .beginner: return .neonCyan
        case .intermediate: return .solarGold
        case .advanced: return .cosmicPurple
        case .pro: return .neonMagenta
        }
    }

    /// "2.0" — compact numeric label for segments and chips.
    var shortLabel: String { value.duprString() }

    /// "2.0 – New to the Game" — full label for pickers.
    var pickerLabel: String { "\(shortLabel) – \(name)" }

    /// The level whose band contains `value` (floor semantics): 4.2 → advanced,
    /// 2.3 → newToTheGame. Mirrors the ranges `DUPRBadge` used before this
    /// type existed, extended downward.
    static func nearest(to value: Decimal) -> SkillLevel {
        allCases.last(where: { $0.value <= value }) ?? .newToTheGame
    }

    /// The next tier up — used to default a target rating one step above the
    /// player's current level. Pro has nowhere to go but pro.
    var nextUp: SkillLevel {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return self }
        return all[index + 1]
    }
}
