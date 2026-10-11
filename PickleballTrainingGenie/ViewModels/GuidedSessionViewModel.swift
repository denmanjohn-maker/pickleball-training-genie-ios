import Foundation
import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit
import UserNotifications

/// Drives a guided training session over a generated workout plan: sequencing,
/// per-drill countdowns, pause/skip, and transition cues. This is the piece
/// that turns a workout *plan* into a coached *session* — keeping time and
/// saying "switch" is most of what an in-person coach physically does.
///
/// Timing is anchored to a wall-clock end date rather than a tick counter, so
/// a locked phone or a backgrounded app can't make the countdown drift. When
/// the app leaves the foreground mid-drill a local notification fires at the
/// moment the drill ends, and spoken cues play through the audio session so
/// the phone can sit face-down on a bench.
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
    /// Spoken cues ("Switch. Next: dinking, five minutes."). Persisted so the
    /// choice sticks between sessions.
    @Published var voiceCuesEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceCuesEnabled, forKey: Self.voiceCuesKey) }
    }

    nonisolated static let voiceCuesKey = "guidedSession.voiceCues"

    let steps: [Step]
    let workout: WorkoutPlanResponse

    private let now: () -> Date
    /// False in unit tests: skips the idle timer, audio session, haptics and
    /// notifications, which need a running app.
    private let integratesWithSystem: Bool
    private var timer: Timer?
    /// When the current timed step ends. Everything about the countdown is
    /// derived from this; the timer only exists to refresh the display.
    private var stepEndDate: Date?
    /// Seconds left at the moment the player paused.
    private var pausedRemaining: Int?
    private var warnedTenSeconds = false
    private let speaker: SessionCueSpeaker
    private static let stepEndNotificationID = "guided-session-step-end"

    init(
        workout: WorkoutPlanResponse,
        now: @escaping () -> Date = { Date() },
        integratesWithSystem: Bool = true
    ) {
        self.workout = workout
        self.now = now
        self.integratesWithSystem = integratesWithSystem
        self.speaker = SessionCueSpeaker(managesAudioSession: integratesWithSystem)
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
        let defaults = UserDefaults.standard
        voiceCuesEnabled = defaults.object(forKey: Self.voiceCuesKey) == nil
            ? true
            : defaults.bool(forKey: Self.voiceCuesKey)
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

    /// 1-based so the bar shows progress on the first step and fills
    /// completely on the last, matching the "Step x of N" label beside it.
    var progressFraction: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(min(stepIndex + 1, steps.count)) / Double(steps.count)
    }

    // MARK: - Lifecycle

    func start() {
        if integratesWithSystem {
            // A session dies the moment the screen locks mid-drill; keep it awake.
            UIApplication.shared.isIdleTimerDisabled = true
            configureAudioSession()
            // So the step-end alert can reach a pocketed phone. Only prompts
            // the first time; a refusal just means no alert.
            Task { _ = await TrainingReminders.requestAuthorization() }
        }
        enterCurrentStep()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if integratesWithSystem {
            UIApplication.shared.isIdleTimerDisabled = false
            cancelStepEndNotification()
            speaker.stop()
        }
    }

    /// Call from the view's `scenePhase` observer. In the background the timer
    /// can't fire, so a notification stands in for the "switch" cue; coming
    /// back, the countdown catches up to the wall clock in one tick.
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            if let end = stepEndDate, !isPaused, !isFinished {
                scheduleStepEndNotification(at: end)
            }
        case .active:
            cancelStepEndNotification()
            if stepEndDate != nil { tick() }
        default:
            break
        }
    }

    // MARK: - Controls

    func togglePause() {
        if isPaused {
            guard let remaining = pausedRemaining else { return }
            stepEndDate = now().addingTimeInterval(TimeInterval(remaining))
            pausedRemaining = nil
            isPaused = false
            startTimer()
        } else {
            guard stepEndDate != nil, let remaining = remainingSeconds else { return }
            pausedRemaining = remaining
            stepEndDate = nil
            isPaused = true
            timer?.invalidate()
            cancelStepEndNotification()
        }
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
        if isPaused, let remaining = pausedRemaining {
            pausedRemaining = remaining + 60
            remainingSeconds = remaining + 60
        } else if let end = stepEndDate {
            stepEndDate = end.addingTimeInterval(60)
            refreshRemaining()
        } else {
            return
        }
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
        pausedRemaining = nil
        timer?.invalidate()
        cancelStepEndNotification()
        switch currentStep {
        case .drill(_, let item):
            let seconds = max(item.durationMinutes, 1) * 60
            stepEndDate = now().addingTimeInterval(TimeInterval(seconds))
            remainingSeconds = seconds
            startTimer()
        default:
            stepEndDate = nil
            remainingSeconds = nil
        }
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        stepEndDate = nil
        isFinished = true
        if integratesWithSystem {
            UIApplication.shared.isIdleTimerDisabled = false
            cancelStepEndNotification()
        }
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

    private func refreshRemaining() {
        guard let end = stepEndDate else { return }
        remainingSeconds = max(Int(ceil(end.timeIntervalSince(now()))), 0)
    }

    /// Re-derives the countdown from the clock and fires cues. Internal (not
    /// private) so tests can drive time without spinning the run loop.
    func tick() {
        guard !isPaused, !isFinished, stepEndDate != nil else { return }
        refreshRemaining()
        let remaining = remainingSeconds ?? 0
        if remaining > 0, remaining <= 10, !warnedTenSeconds {
            warnedTenSeconds = true
            cue(.almostDone)
        }
        if remaining <= 0 {
            // Timer ran out — the drill counts as completed.
            if case .drill(let index, _) = currentStep {
                outcomes[index] = .completed
            }
            cue(.drillDone)
            advance()
        }
    }

    // MARK: - Background notification

    private func scheduleStepEndNotification(at date: Date) {
        guard integratesWithSystem else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time — switch!"
        content.body = upcomingPhrase().isEmpty
            ? "Open Pickleball Genie to finish your session."
            : upcomingPhrase()
        content.sound = .default
        let interval = max(date.timeIntervalSince(now()), 1)
        let request = UNNotificationRequest(
            identifier: Self.stepEndNotificationID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelStepEndNotification() {
        guard integratesWithSystem else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.stepEndNotificationID])
    }

    // MARK: - Audio

    /// `.playback` so cues are heard with the ring switch on silent — a court
    /// is loud and the phone is usually in a pocket. `.duckOthers` lowers the
    /// player's music only while the session is *active*, and
    /// `SessionCueSpeaker` activates it just for the duration of each cue, so
    /// music plays at full volume between cues.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        } catch {
            AppLog.session.error("Audio session unavailable: \(error.localizedDescription)")
        }
    }

    // MARK: - Cues

    private enum Cue {
        case transition
        case almostDone
        case drillDone
        case sessionDone
    }

    /// "Next: Dink Rally. 5 minutes." for whatever follows the current step,
    /// or "" at the end of the plan.
    func upcomingPhrase() -> String {
        guard let next = nextStep else { return "" }
        switch next {
        case .drill(_, let item):
            let minutes = max(item.durationMinutes, 1)
            return "Next: \(item.title). \(minutes) \(minutes == 1 ? "minute" : "minutes")."
        case .cooldown:
            return "Next: cool down."
        case .warmup:
            return "Next: warm up."
        }
    }

    private func cue(_ cue: Cue) {
        guard integratesWithSystem else { return }
        switch cue {
        case .transition:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            speak(upcomingPhrase().isEmpty ? "" : "Let's go. \(upcomingPhrase())")
        case .almostDone:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            speak("Ten seconds.")
        case .drillDone:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            AudioServicesPlaySystemSound(1057) // short tick — audible over court noise
            speak(upcomingPhrase().isEmpty ? "" : "Switch. \(upcomingPhrase())")
        case .sessionDone:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            AudioServicesPlaySystemSound(1025)
            speak("Session complete. Nice work.")
        }
    }

    private func speak(_ text: String) {
        guard voiceCuesEnabled, !text.isEmpty else { return }
        speaker.speak(text)
    }

    static func formatSeconds(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Owns the speech synthesizer for the life of a session (it must be retained
/// while speaking). The newest cue always replaces whatever is still playing —
/// after a quick skip, a stale "Next: …" is worse than silence — and the
/// audio session is active only while an utterance plays, so other apps'
/// audio is ducked for a few seconds per cue rather than the whole workout.
@MainActor
final class SessionCueSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    /// False in unit tests, where there is no audio hardware to activate.
    private let managesAudioSession: Bool

    init(managesAudioSession: Bool) {
        self.managesAudioSession = managesAudioSession
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        if managesAudioSession {
            try? AVAudioSession.sharedInstance().setActive(true)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.preUtteranceDelay = 0.1
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        releaseAudioSession()
    }

    /// Hands audio focus back as soon as the queue is empty. Checked on the
    /// main actor after the current cue (if any) has been enqueued, so a
    /// stop-then-speak pair doesn't release the session mid-utterance.
    private func releaseAudioSession() {
        guard managesAudioSession, !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.releaseAudioSession() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.releaseAudioSession() }
    }
}
