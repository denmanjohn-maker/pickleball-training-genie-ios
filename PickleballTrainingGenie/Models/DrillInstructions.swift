import Foundation

/// The structured form of a drill description.
///
/// Curated drills on the backend follow a fixed template — a one-sentence
/// summary, then `Setup:`, `How to run it:`, `Goal:` and `Coaching cue:` lines —
/// so the app can render labelled sections instead of one prose blob. Scraped
/// or older drills have no labels; they parse to a summary only and render as
/// plain text, exactly as before.
struct DrillInstructions: Equatable, Sendable {
    var summary: String
    var setup: String?
    var howToRun: String?
    var goal: String?
    var coachingCue: String?

    var hasSections: Bool {
        setup != nil || howToRun != nil || goal != nil || coachingCue != nil
    }

    private enum SectionLabel: String, CaseIterable {
        case setup = "Setup:"
        case howToRun = "How to run it:"
        case goal = "Goal:"
        case coachingCue = "Coaching cue:"
    }

    static func parse(_ description: String) -> DrillInstructions {
        var result = DrillInstructions(summary: "")
        var summaryLines: [String] = []
        var current: SectionLabel?

        for rawLine in description.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if let match = Self.split(line) {
                current = match.label
                result.set(match.label, match.body)
            } else if let label = current {
                // Continuation of the current section (wrapped text).
                result.set(label, [result.value(label), line].compactMap { $0 }.joined(separator: " "))
            } else {
                summaryLines.append(line)
            }
        }

        result.summary = summaryLines.joined(separator: " ")
        if result.summary.isEmpty && !result.hasSections {
            result.summary = description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    /// Splits "Label: body" when the line starts with a known label.
    private static func split(_ line: String) -> (label: SectionLabel, body: String)? {
        for label in SectionLabel.allCases where line.hasPrefix(label.rawValue) {
            let body = line.dropFirst(label.rawValue.count).trimmingCharacters(in: .whitespaces)
            return (label, body)
        }
        return nil
    }

    private mutating func set(_ label: SectionLabel, _ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        let stored: String? = trimmed.isEmpty ? nil : trimmed
        switch label {
        case .setup: setup = stored
        case .howToRun: howToRun = stored
        case .goal: goal = stored
        case .coachingCue: coachingCue = stored
        }
    }

    private func value(_ label: SectionLabel) -> String? {
        switch label {
        case .setup: return setup
        case .howToRun: return howToRun
        case .goal: return goal
        case .coachingCue: return coachingCue
        }
    }

    /// Splits the backend's comma-separated `equipment` string into pills.
    static func equipmentItems(from equipment: String?) -> [String] {
        guard let equipment else { return [] }
        return equipment
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

extension Drill {
    var instructions: DrillInstructions { DrillInstructions.parse(description) }
    var equipmentItems: [String] { DrillInstructions.equipmentItems(from: equipment) }
}

extension WorkoutDrillItem {
    /// Full instructions for the catalog drill behind this plan item, when the
    /// backend could match one; nil for plans from older backends or items the
    /// model renamed.
    var instructions: DrillInstructions? { description.map(DrillInstructions.parse) }
    var equipmentItems: [String] { DrillInstructions.equipmentItems(from: equipment) }
}
