import Foundation

/// Erases every trace of the signed-in account from this device.
///
/// Deleting an account server-side doesn't touch what the app has written
/// locally, and some of that data — practice video clips especially — exists
/// nowhere else. Without this, "permanently delete my account" would leave
/// favorites, assessment results, cached workouts and reminder notifications
/// behind for whoever signs in on the phone next.
///
/// This is the single place that knows the full list, so a feature that adds
/// new local storage has one obvious file to update. Called only from
/// `AuthViewModel.deleteAccount()` — signing out deliberately keeps everything
/// so a returning player finds things as they left them.
@MainActor
enum LocalDataPurge {
    /// UserDefaults keys owned by types that don't expose their own reset.
    ///
    /// `mainTab.selection` is intentionally absent: it's `@SceneStorage`, which
    /// the system manages as scene-restoration state rather than UserDefaults,
    /// and it only decides which tab opens first.
    private static let defaultsKeys = [
        "tutorial.hasSeenAppIntro",     // ContentView
        "tournaments.lastCityId",       // TournamentsViewModel
        "training.weeklyGoal",          // TrainingStats
        "assessment.result",            // SkillAssessment
        TrainingReminders.enabledKey,
        TrainingReminders.weekdaysKey,
        TrainingReminders.hourKey,
        TrainingReminders.minuteKey,
    ]

    static func purgeAll() async {
        let defaults = UserDefaults.standard
        for key in defaultsKeys {
            defaults.removeObject(forKey: key)
        }

        // These two hold their data in memory as well as on disk, so they have
        // to clear themselves — removing the backing store behind them would
        // leave the UI showing data that no longer exists.
        FavoriteDrills.shared.clearAll()
        VideoReviewStore.shared.deleteAll()

        OfflineCache.clearAll()

        // Otherwise reminders keep firing for an account that's gone.
        await TrainingReminders.cancelAll()
    }
}
