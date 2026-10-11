import XCTest
@testable import PickleballTrainingGenie

final class TrainingStatsTests: XCTestCase {
    private let calendar = Fixtures.utcCalendar
    // A Wednesday.
    private let now = Fixtures.date(2026, 8, 5, hour: 15)

    private func day(_ offset: Int, hour: Int = 9) -> Date {
        calendar.date(byAdding: .day, value: offset, to: Fixtures.date(2026, 8, 5, hour: hour))!
    }

    func testNoSessionsNoStreak() {
        XCTAssertEqual(TrainingStats.currentStreakDays(sessionDates: [], calendar: calendar, now: now), 0)
    }

    func testConsecutiveDaysEndingToday() {
        let dates = [day(0), day(-1), day(-2)]
        XCTAssertEqual(TrainingStats.currentStreakDays(sessionDates: dates, calendar: calendar, now: now), 3)
    }

    func testStreakSurvivesUntilTodayIsOver() {
        // Trained yesterday and the day before, not yet today: still a 2-day streak.
        let dates = [day(-1), day(-2)]
        XCTAssertEqual(TrainingStats.currentStreakDays(sessionDates: dates, calendar: calendar, now: now), 2)
    }

    func testGapBreaksStreak() {
        let dates = [day(-2), day(-3)]
        XCTAssertEqual(TrainingStats.currentStreakDays(sessionDates: dates, calendar: calendar, now: now), 0)
    }

    func testMultipleSessionsOnOneDayCountOnce() {
        let dates = [day(0, hour: 8), day(0, hour: 18), day(-1)]
        XCTAssertEqual(TrainingStats.currentStreakDays(sessionDates: dates, calendar: calendar, now: now), 2)
    }

    func testSessionsThisWeek() {
        // Week of Sun Aug 2 – Sat Aug 8 2026 (gregorian default firstWeekday = Sunday).
        let dates = [day(0), day(-2), day(-3), day(-10), day(4)]
        XCTAssertEqual(TrainingStats.sessionsThisWeek(sessionDates: dates, calendar: calendar, now: now), 4)
    }
}
