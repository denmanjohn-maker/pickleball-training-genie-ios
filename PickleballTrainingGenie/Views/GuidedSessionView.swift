import SwiftUI

/// Full-screen guided session runner: one step at a time, a big countdown,
/// next-up preview, and a summary that saves to history. Presented as a
/// full-screen cover from `WorkoutView`.
struct GuidedSessionView: View {
    @EnvironmentObject var drillsViewModel: DrillsViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: GuidedSessionViewModel
    @State private var showExitConfirmation = false

    init(workout: WorkoutPlanResponse) {
        _session = StateObject(wrappedValue: GuidedSessionViewModel(workout: workout))
    }

    var body: some View {
        ZStack {
            SynthwaveGradient()
            if session.isFinished {
                SessionSummaryView(session: session) { ratings, notes in
                    Task {
                        await drillsViewModel.completeWorkout(
                            completedIndices: session.completedDrillIndices,
                            ratings: ratings,
                            notes: notes
                        )
                        // Stay on the summary if the save failed (e.g. no
                        // signal) so the player can retry without losing
                        // their completed/skipped state. completeWorkout
                        // clears workoutError on entry, so nil here means
                        // this save succeeded.
                        if drillsViewModel.workoutError == nil {
                            dismiss()
                        }
                    }
                } onDiscard: {
                    dismiss()
                }
            } else {
                activeSession
            }
        }
        .onAppear { session.start() }
        .onDisappear { session.stop() }
    }

    private var activeSession: some View {
        VStack(spacing: 20) {
            // Top bar
            HStack {
                Button {
                    showExitConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 44, height: 44)
                }
                // Anchored to the button so the iPad popover points at it.
                .confirmationDialog(
                    "End this session?",
                    isPresented: $showExitConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("End Session", role: .destructive) { dismiss() }
                    Button("Keep Training", role: .cancel) {}
                } message: {
                    Text("Progress from this session won't be saved.")
                }
                Spacer()
                Text("Step \(session.stepIndex + 1) of \(session.steps.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                // Balances the close button so the step label stays centered.
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal)

            ProgressView(value: session.progressFraction)
                .tint(.neonMagenta)
                .padding(.horizontal)

            Spacer()

            switch session.currentStep {
            case .warmup(let text):
                UntimedStepCard(
                    icon: "flame.fill",
                    color: .orange,
                    title: "Warm-Up",
                    text: text,
                    buttonLabel: "Start Drills"
                ) {
                    session.continueFromUntimedStep()
                }
            case .cooldown(let text):
                UntimedStepCard(
                    icon: "snowflake",
                    color: .blue,
                    title: "Cool-Down",
                    text: text,
                    buttonLabel: "Finish Session"
                ) {
                    session.continueFromUntimedStep()
                }
            case .drill(_, let item):
                drillCard(item)
            case nil:
                EmptyView()
            }

            Spacer()

            if let next = session.nextStep {
                HStack(spacing: 8) {
                    Text("Next up:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Text(next.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .padding(.bottom, 12)
            }
        }
        .padding(.vertical)
    }

    private func drillCard(_ item: WorkoutDrillItem) -> some View {
        VStack(spacing: 20) {
            CategoryBadge(category: item.category)

            Text(item.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let remaining = session.remainingSeconds {
                Text(GuidedSessionViewModel.formatSeconds(remaining))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(remaining <= 10 ? .neonMagenta : .white)
                    .neonGlow(remaining <= 10 ? .neonMagenta : .neonCyan, radius: 12)
                    .accessibilityLabel("Time remaining \(GuidedSessionViewModel.formatSeconds(remaining))")
            }

            ScrollView {
                Text(item.coachingNotes)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .padding()
                    .readableWidth()
            }
            .frame(maxHeight: 140)

            // Controls
            HStack(spacing: 14) {
                ControlButton(
                    icon: session.isPaused ? "play.fill" : "pause.fill",
                    label: session.isPaused ? "Resume" : "Pause"
                ) {
                    session.togglePause()
                }
                ControlButton(icon: "checkmark", label: "Done", tint: .green) {
                    session.completeCurrentDrill()
                }
                ControlButton(icon: "plus", label: "+1 min") {
                    session.addMinute()
                }
                ControlButton(icon: "forward.fill", label: "Skip", tint: .white.opacity(0.6)) {
                    session.skipCurrentStep()
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Pieces

private struct UntimedStepCard: View {
    let icon: String
    let color: Color
    let title: String
    let text: String
    let buttonLabel: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(color)
            }
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            ScrollView {
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .readableWidth()
            }
            .frame(maxHeight: 180)
            Button(action: onContinue) {
                Text(buttonLabel)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
    }
}

private struct ControlButton: View {
    let icon: String
    let label: String
    var tint: Color = .neonCyan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(tint)
            .frame(width: 64, height: 60)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
        }
        .accessibilityLabel(label)
    }
}

private struct SessionSummaryView: View {
    @ObservedObject var session: GuidedSessionViewModel
    let onSave: (_ ratings: [Int: Int], _ notes: String?) -> Void
    let onDiscard: () -> Void
    @EnvironmentObject var drillsViewModel: DrillsViewModel
    @State private var ratings: [Int: Int] = [:]
    @State private var journalNote = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 96, height: 96)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                }
                .padding(.top, 24)

                Text("Session Complete!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("\(session.completedDrillCount) of \(session.totalDrillCount) drills completed")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                // Per-drill "how did that go?" — the feedback the AI needs to
                // adapt future workouts. Skipped drills aren't rated.
                VStack(alignment: .leading, spacing: 14) {
                    Text("How did each drill go?")
                        .font(.headline)
                        .foregroundColor(.white)
                    ForEach(Array(session.workout.drills.enumerated()), id: \.element.id) { index, item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Image(systemName: session.completedDrillIndices.contains(index)
                                      ? "checkmark.circle.fill" : "forward.circle")
                                    .foregroundColor(session.completedDrillIndices.contains(index) ? .green : .white.opacity(0.4))
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                                Spacer()
                            }
                            if session.completedDrillIndices.contains(index) {
                                DrillRatingControl(rating: ratingBinding(for: index))
                                    .padding(.leading, 30)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Session notes (optional)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    TextField(
                        "",
                        text: $journalNote,
                        prompt: Text("What worked? What felt off?")
                            .foregroundColor(.white.opacity(0.35)),
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                    .padding(10)
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                VStack(spacing: 10) {
                    Button {
                        onSave(ratings, journalNote)
                    } label: {
                        HStack {
                            if drillsViewModel.isCompletingWorkout {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                            }
                            Text(drillsViewModel.isCompletingWorkout ? "Saving…" : "Save to History")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(drillsViewModel.isCompletingWorkout)

                    Button("Discard Session") {
                        onDiscard()
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                }
                .padding(.horizontal)
                .padding(.bottom, 12)

                if let error = drillsViewModel.workoutError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .readableWidth()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func ratingBinding(for index: Int) -> Binding<Int?> {
        Binding(
            get: { ratings[index] },
            set: { ratings[index] = $0 }
        )
    }
}

/// Three-option feel rating mapping onto the backend's 1–5 scale:
/// struggled = 1, getting there = 3, nailed it = 5. Tap again to clear.
struct DrillRatingControl: View {
    @Binding var rating: Int?

    private static let options: [(value: Int, icon: String, label: String)] = [
        (1, "hand.thumbsdown.fill", "Struggled"),
        (3, "minus.circle.fill", "Getting there"),
        (5, "hand.thumbsup.fill", "Nailed it")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Self.options, id: \.value) { option in
                let isSelected = rating == option.value
                Button {
                    rating = isSelected ? nil : option.value
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: option.icon)
                            .font(.caption)
                        Text(option.label)
                            .font(.caption2)
                    }
                    .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(isSelected ? Color.neonCyan : Color.white.opacity(0.08))
                    .cornerRadius(8)
                }
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
