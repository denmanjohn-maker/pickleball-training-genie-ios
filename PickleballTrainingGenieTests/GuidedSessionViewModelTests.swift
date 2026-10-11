import XCTest
import SwiftUI
@testable import PickleballTrainingGenie

/// Controllable wall clock for the session's `now` closure. Top-level (not
/// nested in the main-actor test class) so the closure can read it freely.
final class TestClock {
    var now = Fixtures.date(2026, 8, 5)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

@MainActor
final class GuidedSessionViewModelTests: XCTestCase {
    private var clock: TestClock!

    override func setUp() {
        super.setUp()
        clock = TestClock()
    }

    private func makeSession(
        warmup: String? = "Warm up.",
        drills: [WorkoutDrillItem] = [
            Fixtures.workoutItem(title: "Dink Rally", minutes: 5),
            Fixtures.workoutItem(title: "Third Shot Drops", category: "Drops", minutes: 1)
        ],
        cooldown: String? = "Cool down."
    ) -> GuidedSessionViewModel {
        let clock: TestClock = self.clock
        return GuidedSessionViewModel(
            workout: Fixtures.workout(warmup: warmup, drills: drills, cooldown: cooldown),
            now: { clock.now },
            integratesWithSystem: false
        )
    }

    func testBuildsStepsInOrder() {
        let session = makeSession()
        XCTAssertEqual(session.steps.count, 4)
        XCTAssertEqual(session.steps.map(\.title), ["Warm-Up", "Dink Rally", "Third Shot Drops", "Cool-Down"])
        XCTAssertEqual(session.progressFraction, 0.25)
    }

    func testSkipsEmptyWarmupAndCooldown() {
        let session = makeSession(warmup: nil, cooldown: "")
        XCTAssertEqual(session.steps.map(\.title), ["Dink Rally", "Third Shot Drops"])
    }

    func testCountdownFollowsTheClockNotTheTickCount() {
        let session = makeSession()
        session.start()
        XCTAssertNil(session.remainingSeconds, "Warm-up is untimed")
        session.continueFromUntimedStep()
        XCTAssertEqual(session.remainingSeconds, 300)

        clock.advance(120)
        session.tick()
        XCTAssertEqual(session.remainingSeconds, 180)

        // A long gap (phone locked) is caught up in a single tick.
        clock.advance(170)
        session.tick()
        XCTAssertEqual(session.remainingSeconds, 10)
        session.stop()
    }

    func testTimerExpiryCompletesDrillAndAdvances() {
        let session = makeSession()
        session.start()
        session.continueFromUntimedStep()
        clock.advance(300)
        session.tick()
        XCTAssertEqual(session.outcomes[0], .completed)
        XCTAssertEqual(session.currentStep?.title, "Third Shot Drops")
        XCTAssertEqual(session.remainingSeconds, 60)
        session.stop()
    }

    func testPauseFreezesTimeAndResumeContinues() {
        let session = makeSession()
        session.start()
        session.continueFromUntimedStep()
        clock.advance(60)
        session.tick()
        XCTAssertEqual(session.remainingSeconds, 240)

        session.togglePause()
        XCTAssertTrue(session.isPaused)
        clock.advance(600)
        session.tick()
        XCTAssertEqual(session.remainingSeconds, 240, "Paused time must not count")

        session.togglePause()
        XCTAssertFalse(session.isPaused)
        clock.advance(40)
        session.tick()
        XCTAssertEqual(session.remainingSeconds, 200)
        session.stop()
    }

    func testAddMinuteWhileRunningAndWhilePaused() {
        let session = makeSession()
        session.start()
        session.continueFromUntimedStep()
        session.addMinute()
        XCTAssertEqual(session.remainingSeconds, 360)
        session.togglePause()
        session.addMinute()
        XCTAssertEqual(session.remainingSeconds, 420)
        session.togglePause()
        clock.advance(20)
        session.tick()
        XCTAssertEqual(session.remainingSeconds, 400)
        session.stop()
    }

    func testCompleteEarlyAndSkipRecordOutcomes() {
        let session = makeSession()
        session.start()
        session.continueFromUntimedStep()
        session.completeCurrentDrill()
        session.skipCurrentStep()
        XCTAssertEqual(session.outcomes[0], .completed)
        XCTAssertEqual(session.outcomes[1], .skipped)
        XCTAssertEqual(session.completedDrillIndices, [0])
        XCTAssertEqual(session.currentStep?.title, "Cool-Down")
        XCTAssertFalse(session.isFinished)
        session.continueFromUntimedStep()
        XCTAssertTrue(session.isFinished)
        session.stop()
    }

    func testReturningToForegroundAfterDrillEndedAdvances() {
        let session = makeSession()
        session.start()
        session.continueFromUntimedStep()
        session.handleScenePhase(.background)
        clock.advance(400)
        session.handleScenePhase(.active)
        XCTAssertEqual(session.outcomes[0], .completed)
        XCTAssertEqual(session.currentStep?.title, "Third Shot Drops")
        session.stop()
    }

    func testUpcomingPhraseDescribesNextStep() {
        let session = makeSession()
        XCTAssertEqual(session.upcomingPhrase(), "Next: Dink Rally. 5 minutes.")
        session.start()
        session.continueFromUntimedStep()
        XCTAssertEqual(session.upcomingPhrase(), "Next: Third Shot Drops. 1 minute.")
        session.skipCurrentStep()
        XCTAssertEqual(session.upcomingPhrase(), "Next: cool down.")
        session.skipCurrentStep()
        XCTAssertEqual(session.upcomingPhrase(), "")
        session.stop()
    }

    func testFormatSeconds() {
        XCTAssertEqual(GuidedSessionViewModel.formatSeconds(0), "0:00")
        XCTAssertEqual(GuidedSessionViewModel.formatSeconds(65), "1:05")
        XCTAssertEqual(GuidedSessionViewModel.formatSeconds(600), "10:00")
    }
}
