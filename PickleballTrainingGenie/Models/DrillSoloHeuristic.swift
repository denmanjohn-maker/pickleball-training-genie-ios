import Foundation

/// Guesses whether a drill can be run without a partner.
///
/// The backend's `Drill` carries no player count yet (see ROADMAP §6), but the
/// player who can't get coaching usually can't get a drilling partner either,
/// so a "solo" filter is worth having even as a heuristic. Keyword-based on the
/// title and description; replace with a server-side flag when one exists.
enum DrillSoloHeuristic {
    static let soloKeywords: [String] = [
        "solo", "alone", "by yourself", "on your own", "wall", "ball machine",
        "self-feed", "self feed", "drop and hit", "toss and hit", "shadow",
        "no partner", "without a partner"
    ]

    static let partnerKeywords: [String] = [
        "partner", "feeder", "opponent", "teammate", "two players", "2 players",
        "three players", "four players", "with a friend", "coach feeds", "have someone"
    ]

    /// Phrases that *mention* a partner only to say one isn't needed.
    private static let negatedPartnerPhrases: [String] = [
        "no partner", "without a partner", "don't need a partner",
        "doesn't need a partner", "no partner needed", "partner optional"
    ]

    static func isSoloFriendly(title: String, description: String, category: String) -> Bool {
        var text = "\(title) \(description)".lowercased()
        for phrase in negatedPartnerPhrases {
            text = text.replacingOccurrences(of: phrase, with: " solo ")
        }
        if partnerKeywords.contains(where: { text.contains($0) }) {
            return false
        }
        // Serving is inherently a one-person activity unless the text says otherwise.
        if category == "Serving" { return true }
        return soloKeywords.contains(where: { text.contains($0) })
    }
}

extension Drill {
    /// Heuristic — see `DrillSoloHeuristic`.
    var isSoloFriendly: Bool {
        DrillSoloHeuristic.isSoloFriendly(title: title, description: description, category: category)
    }
}
