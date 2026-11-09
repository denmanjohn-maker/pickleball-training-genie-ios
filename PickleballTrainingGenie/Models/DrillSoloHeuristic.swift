import Foundation

/// Guesses whether a drill can be run without a partner.
///
/// The backend now tags every curated drill with `minPlayers`, which wins
/// whenever it is present (see `Drill.isSoloFriendly`). This keyword guess is
/// the fallback for drills from older backends, or scraped rows the server
/// hasn't tagged, so the "Solo-friendly" filter keeps working against any
/// catalog.
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
    /// True when the drill needs nobody else. The server's `minPlayers` tag is
    /// authoritative; the keyword heuristic only fills in when it is missing.
    var isSoloFriendly: Bool {
        if let minPlayers { return minPlayers == 1 }
        return DrillSoloHeuristic.isSoloFriendly(title: title, description: description, category: category)
    }
}
