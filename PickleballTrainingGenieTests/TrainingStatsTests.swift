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
        // `now` is Wed Aug 5 2026. Mon–Wed of that week are in the week whether
        // it starts on Sunday or Monday; Jul 26 and Mon Aug 10 are outside it
        // under both conventions, so this doesn't hinge on the runner's locale.
        let dates = [day(0), day(-1), day(-2), day(-10), day(5)]
        XCTAssertEqual(TrainingStats.sessionsThisWeek(sessionDates: dates, calendar: calendar, now: now), 3)
    }

    func testSessionsThisWeekUsesTheCalendarsOwnWeekBoundaries() {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return XCTFail("Calendar has no week interval")
        }
        let justInside = week.start.addingTimeInterval(60)
        let justOutside = week.start.addingTimeInterval(-60)
        XCTAssertEqual(TrainingStats.sessionsThisWeek(sessionDates: [justInside, justOutside], calendar: calendar, now: now), 1)
    }
}
