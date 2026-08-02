import Foundation

/// Streak and weekly-goal math over completed session dates. Self-directed
/// training lives or dies on habit; these numbers make the habit visible.
enum TrainingStats {
    /// Sessions per week the player is aiming for. Stored locally.
    static var weeklyGoal: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: "training.weeklyGoal")
            return stored > 0 ? stored : 3
        }
        set {
            UserDefaults.standard.set(max(1, newValue), forKey: "training.weeklyGoal")
        }
    }

    /// Consecutive training days ending today or yesterday. Multiple sessions
    /// on one day count once; a streak isn't broken until a full calendar day
    /// passes with no training.
    static func currentStreakDays(
        sessionDates: [Date],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Int {
        let trainedDays = Set(sessionDates.map { calendar.startOfDay(for: $0) })
        guard !trainedDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        // The streak anchors on today if the player already trained today,
        // otherwise on yesterday (today isn't over yet — don't punish it).
        var cursor: Date
        if trainedDays.contains(today) {
            cursor = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  trainedDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while trainedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Sessions completed in the current calendar week.
    static func sessionsThisWeek(
        sessionDates: [Date],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return sessionDates.filter { week.contains($0) }.count
    }
}
