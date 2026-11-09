import SwiftUI

/// Renders a drill's instructions as labelled sections when the description
/// follows the curated template, or as plain prose when it doesn't.
///
/// `compact` uses caption-sized text for use inside cards; `onDark` switches
/// to light text for the guided session's dark full-screen layout.
struct DrillInstructionsView: View {
    let instructions: DrillInstructions
    var compact = false
    var onDark = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 14) {
            if !instructions.summary.isEmpty {
                Text(instructions.summary)
                    .font(compact ? .caption : .body)
                    .fontWeight(instructions.hasSections ? .medium : .regular)
                    .foregroundColor(primaryColor)
                    .lineSpacing(compact ? 2 : 4)
            }
            section("Setup", icon: "square.grid.2x2", text: instructions.setup)
            section("How to run it", icon: "list.number", text: instructions.howToRun)
            section("Goal", icon: "target", text: instructions.goal)
            section("Coaching cue", icon: "lightbulb.fill", text: instructions.coachingCue)
        }
    }

    private var primaryColor: Color { onDark ? .white.opacity(0.9) : .primary }
    private var secondaryColor: Color { onDark ? .white.opacity(0.6) : .secondary }

    @ViewBuilder
    private func section(_ title: String, icon: String, text: String?) -> some View {
        if let text {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(compact ? .caption : .subheadline)
                    .foregroundColor(.neonCyan)
                    .frame(width: compact ? 16 : 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(compact ? .caption2 : .caption)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .foregroundColor(secondaryColor)
                    Text(text)
                        .font(compact ? .caption : .body)
                        .foregroundColor(primaryColor)
                        .lineSpacing(compact ? 2 : 4)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    DrillInstructionsView(instructions: DrillInstructions.parse(
        "Learn the soft dink stroke against a wall.\n\nSetup: Mark a line at net height.\nHow to run it: Dink above the line.\nGoal: 25 in a row.\nCoaching cue: Soft grip."
    ))
    .padding()
}
