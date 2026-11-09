import Foundation

/// Who the player has available to train with. Chosen on the Train tab before
/// a workout is generated, sent to the backend as `playersAvailable`, and
/// compared there against each drill's `minPlayers` (a drill is offered when
/// `minPlayers <= playersAvailable`). Remembered on this device only — it's a
/// per-session fact, not a profile trait.
enum TrainingCompany: Int, CaseIterable, Codable, Sendable {
    case solo = 1
    case partner = 2
    case group = 4

    /// UserDefaults key; listed in `LocalDataPurge` so account deletion clears it.
    static let storageKey = "workout.trainingCompany"

    var title: String {
        switch self {
        case .solo: return "Just me"
        case .partner: return "With a partner"
        case .group: return "Group (3–4)"
        }
    }

    var systemImage: String {
        switch self {
        case .solo: return "person.fill"
        case .partner: return "person.2.fill"
        case .group: return "person.3.fill"
        }
    }

    /// One line under the picker explaining what the choice unlocks.
    var detail: String {
        switch self {
        case .solo: return "Wall, ball machine, self-feed and footwork drills — nobody else needed."
        case .partner: return "Adds drills that need one feeder or rally partner."
        case .group: return "Adds doubles pattern drills for three or four players."
        }
    }

    /// Label for a drill's own requirement, from the backend's `minPlayers`.
    static func label(forMinPlayers minPlayers: Int) -> String {
        switch minPlayers {
        case ...1: return "Solo"
        case 2: return "Partner"
        default: return "Group"
        }
    }

    static func systemImage(forMinPlayers minPlayers: Int) -> String {
        switch minPlayers {
        case ...1: return TrainingCompany.solo.systemImage
        case 2: return TrainingCompany.partner.systemImage
        default: return TrainingCompany.group.systemImage
        }
    }
}
