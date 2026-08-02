import Foundation
import UserNotifications

/// Local training-reminder notifications. Runtime authorization only — no
/// Info.plist key is required for UNUserNotificationCenter.
enum TrainingReminders {
    static let enabledKey = "reminders.enabled"
    static let weekdaysKey = "reminders.weekdays"   // [Int], 1 = Sunday … 7 = Saturday
    static let hourKey = "reminders.hour"
    static let minuteKey = "reminders.minute"

    private static let identifierPrefix = "training-reminder-"

    /// Default: Mon/Wed/Fri at 5pm — a realistic starting cadence.
    static var savedWeekdays: Set<Int> {
        get {
            let stored = UserDefaults.standard.array(forKey: weekdaysKey) as? [Int]
            return Set(stored ?? [2, 4, 6])
        }
        set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: weekdaysKey)
        }
    }

    static var savedTime: (hour: Int, minute: Int) {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: hourKey) != nil else { return (17, 0) }
            return (defaults.integer(forKey: hourKey), defaults.integer(forKey: minuteKey))
        }
        set {
            UserDefaults.standard.set(newValue.hour, forKey: hourKey)
            UserDefaults.standard.set(newValue.minute, forKey: minuteKey)
        }
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Asks for permission if needed. Returns whether notifications are allowed.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    /// Replaces all training reminders with one repeating notification per
    /// selected weekday at the saved time.
    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        await cancelAll()
        guard isEnabled, !savedWeekdays.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to train 🏓"
        content.body = "Your genie has a workout ready. Even 15 minutes moves your game forward."
        content.sound = .default

        let time = savedTime
        for weekday in savedWeekdays {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = time.hour
            components.minute = time.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(weekday)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }
}
