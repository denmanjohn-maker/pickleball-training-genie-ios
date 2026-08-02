import Foundation
import SwiftUI
import AudioToolbox
import UIKit

/// Drives a guided training session over a generated workout plan: sequencing,
/// per-drill countdowns, pause/skip, and transition cues. This is the piece
/// that turns a workout *plan* into a coached *session* — keeping time and
/// saying "switch" is most of what an in-person coach physically does.
@MainActor
final class GuidedSessionViewModel: ObservableObject {
    enum Step: Equatable {
        /// Untimed instruction card — the player advances when ready.
        case warmup(String)
        case drill(index: Int, item: WorkoutDrillItem)
        case cooldown(String)

        var title: String {
            switch self {
            case .warmup: return "Warm-Up"
            case .drill(_, let item): return item.title
            case .cooldown: return "Cool-Down"
            }
        }
    }

    enum DrillOutcome {
        case completed
        case skipped
    }

    @Published private(set) var stepIndex = 0
    /// nil for untimed steps (warmup/cooldown).
    @Published private(set) var remainingSeconds: Int?
    @Published private(set) var isPaused = false
    @Published private(set) var isFinished = false
    @Published private(set) var outcomes: [Int: DrillOutcome] = [:]

    let steps: [Step]
    let workout: WorkoutPlanResponse

    private var timer: Timer?
    private var warnedTenSeconds = false

    init(workout: WorkoutPlanResponse) {
        self.workout = workout
        var built: [Step] = []
        if let warmup = workout.warmup, !warmup.isEmpty {
            built.append(.warmup(warmup))
        }
        for (index, item) in workout.drills.enumerated() {
            built.append(.drill(index: index, item: item))
        }
        if let cooldown = workout.cooldown, !cooldown.isEmpty {
            built.append(.cooldown(cooldown))
        }
        self.steps = built
    }

    var currentStep: Step? {
        steps.indices.contains(stepIndex) ? steps[stepIndex] : nil
    }

    var nextStep: Step? {
        steps.indices.contains(stepIndex + 1) ? steps[stepIndex + 1] : nil
    }

    /// Drill indices to report to `completeWorkout(completedIndices:)`.
    var completedDrillIndices: Set<Int> {
        Set(outcomes.filter { $0.value == .completed }.map(\.key))
    }

    var completedDrillCount: Int { completedDrillIndices.count }

    var totalDrillCount: Int { workout.drills.count }

    var progressFraction: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(min(stepIndex, steps.count)) / Double(steps.count)
    }

    // MARK: - Lifecycle

    func start() {
        // A session dies the moment the screen locks mid-drill; keep it awake.
        UIApplication.shared.isIdleTimerDisabled = true
        enterCurrentStep()
    }

    func stop() {
        UIApplication.shared.isIdleTimerDisabled = false
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Controls

    func togglePause() {
        guard remainingSeconds != nil else { return }
        isPaused.toggle()
    }

    /// "I finished this drill early."
    func completeCurrentDrill() {
        if case .drill(let index, _) = currentStep {
            outcomes[index] = .completed
            cue(.drillDone)
        }
        advance()
    }

    func skipCurrentStep() {
        if case .drill(let index, _) = currentStep {
            outcomes[index] = .skipped
        }
        advance()
    }

    /// Advance from an untimed warmup/cooldown card.
    func continueFromUntimedStep() {
        cue(.transition)
        advance()
    }

    func addMinute() {
        guard let remaining = remainingSeconds else { return }
        remainingSeconds = remaining + 60
        warnedTenSeconds = false
    }

    // MARK: - Internals

    private func advance() {
        if stepIndex + 1 < steps.count {
            stepIndex += 1
            enterCurrentStep()
        } else {
            finish()
        }
    }

    private func enterCurrentStep() {
        warnedTenSeconds = false
        isPaused = false
        switch currentStep {
        case .drill(_, let item):
            remainingSeconds = max(item.durationMinutes, 1) * 60
            startTimer()
        default:
            remainingSeconds = nil
            timer?.invalidate()
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        isFinished = true
        UIApplication.shared.isIdleTimerDisabled = false
        cue(.sessionDone)
    }

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        // .common keeps the countdown running while the user scrolls.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard !isPaused, !isFinished, let remaining = remainingSeconds else { return }
        let next = remaining - 1
        remainingSeconds = max(next, 0)
        if next == 10, !warnedTenSeconds {
            warnedTenSeconds = true
            cue(.almostDone)
        }
        if next <= 0 {
            // Timer ran out — the drill counts as completed.
            if case .drill(let index, _) = currentStep {
                outcomes[index] = .completed
            }
            cue(.drillDone)
            advance()
        }
    }

    // MARK: - Cues

    private enum Cue {
        case transition
        case almostDone
        case drillDone
        case sessionDone
    }

    private func cue(_ cue: Cue) {
        switch cue {
        case .transition:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .almostDone:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .drillDone:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            AudioServicesPlaySystemSound(1057) // short tick — audible over court noise
        case .sessionDone:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            AudioServicesPlaySystemSound(1025)
        }
    }

    static func formatSeconds(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
