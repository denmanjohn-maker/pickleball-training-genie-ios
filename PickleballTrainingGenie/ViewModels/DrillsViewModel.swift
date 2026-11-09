import Foundation
import SwiftUI

@MainActor
class DrillsViewModel: ObservableObject {
    @Published var drills: [Drill] = []
    @Published var recommendations: [Drill] = []
    @Published var workout: WorkoutPlanResponse?
    @Published var completedWorkoutDrillIndices: Set<Int> = []
    @Published var reviewSavedWorkout = false
    @Published var isLoadingDrills = false
    @Published var isLoadingRecommendations = false
    @Published var isGeneratingWorkout = false
    @Published var drillsError: String?
    @Published var recommendationsError: String?
    @Published var workoutError: String?
    @Published var completedDrillIds: Set<String> = []
    @Published var selectedCategory: String?
    @Published var selectedLevel: Decimal?
    @Published var workoutDuration: Int = 30
    /// Who the player has to train with today. Sent with workout and
    /// recommendation requests so the server only offers drills they can
    /// actually run. Remembered on this device; the Train tab lets them change
    /// it before every generate.
    @Published var trainingCompany: TrainingCompany {
        didSet {
            defaults.set(trainingCompany.rawValue, forKey: TrainingCompany.storageKey)
            // The recommendations on screen were fetched for the old choice.
            // Drop them so the next screen that needs them asks again, and
            // make sure a reply still in flight for the old choice can't
            // repopulate them.
            if oldValue != trainingCompany { invalidateRecommendations() }
        }
    }
    @Published var isCompletingWorkout = false
    @Published var workoutCompletedSuccessfully = false
    /// Set when the drills list is showing cached content because the network
    /// failed — the value is when that cache was saved.
    @Published var cachedDrillsDate: Date?
    /// Set when recommendations are being served from cache after a network
    /// failure.
    @Published var cachedRecommendationsDate: Date?
    /// Set when the current workout was restored from disk (e.g. generated at
    /// home, opened later at the court with no signal).
    @Published var cachedWorkoutDate: Date?

    /// The drill library is public content and cached globally; the
    /// recommendations and workout caches are personalized, so their keys are
    /// scoped per user — a shared device must never surface one account's
    /// workout to another. Recommendations are further scoped by training
    /// company, so an offline relaunch after switching to "Just me" can't
    /// restore drills that need a partner.
    private let drillsCacheKey = "drills"
    private let personalCacheScope: String
    private let workoutCacheKey: String

    private func recommendationsCacheKey(for company: TrainingCompany) -> String {
        "recommendations\(personalCacheScope)-players\(company.rawValue)"
    }

    let drillCategories = [
        "Dinking", "Drops", "Volleys", "Serving", "Returns",
        "Lobs", "Resets", "Attacking", "Movement", "General"
    ]

    var filteredDrills: [Drill] {
        let base = categoryFilteredDrills
        guard let level = selectedLevel else { return base }
        let exact = base.filter { $0.targetDUPRLevel == level }
        if !exact.isEmpty { return exact }
        guard let fallback = nearestPopulatedLevel(to: level, in: base) else { return [] }
        return base.filter { $0.targetDUPRLevel == fallback }
    }

    /// Non-nil when the selected level has no drills and the list is showing
    /// the nearest level that does (e.g. a backend that hasn't tagged 2.0/2.5
    /// content yet). A brand-new player should never meet an empty screen.
    var levelFallbackNotice: (requested: Decimal, showing: Decimal)? {
        guard let level = selectedLevel else { return nil }
        let base = categoryFilteredDrills
        guard !base.contains(where: { $0.targetDUPRLevel == level }),
              let fallback = nearestPopulatedLevel(to: level, in: base) else { return nil }
        return (requested: level, showing: fallback)
    }

    private var categoryFilteredDrills: [Drill] {
        drills.filter { selectedCategory == nil || $0.category == selectedCategory }
    }

    /// Closest level (by absolute distance) that has at least one drill,
    /// preferring the easier level on a tie.
    private func nearestPopulatedLevel(to level: Decimal, in drills: [Drill]) -> Decimal? {
        let populated = Set(drills.map(\.targetDUPRLevel))
        return populated.min { a, b in
            let da = abs(a - level), db = abs(b - level)
            return da == db ? a < b : da < db
        }
    }

    private let client: PickleballTrainingGenieClient
    private let trainingStreakStore: TrainingStreakStore?
    private let defaults: UserDefaults
    private var recommendationsSavedAt: Date?
    /// Bumped whenever the recommendations become invalid (training company
    /// changed); a fetch compares its own copy on return and discards itself
    /// if it is no longer current.
    private var recommendationsRequestID = 0

    var workoutActionTitle: String {
        workout == nil ? "Set Up a Workout" : "Review Saved Workout"
    }

    init(
        client: PickleballTrainingGenieClient,
        userId: String? = nil,
        trainingStreakStore: TrainingStreakStore? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.trainingStreakStore = trainingStreakStore
        self.defaults = defaults
        // Default to training alone: the app exists for players who can't get
        // a coach, and they usually can't get a partner either. A missing key
        // reads as 0, which is not a valid case, so the fallback applies.
        trainingCompany = TrainingCompany(rawValue: defaults.integer(forKey: TrainingCompany.storageKey)) ?? .solo
        let scope = userId.map { "-\($0)" } ?? ""
        personalCacheScope = scope
        workoutCacheKey = "currentWorkout\(scope)"
        // Recommendations used to be cached without the training company in
        // the key; that entry can't be trusted for any choice, so drop it.
        OfflineCache.remove(key: "recommendations\(scope)")
        // A workout generated earlier survives restarts, so it's still there
        // at a court with no signal. Cleared when a session is saved.
        if let cached = OfflineCache.load(WorkoutPlanResponse.self, key: workoutCacheKey) {
            workout = cached.value
            cachedWorkoutDate = cached.savedAt
        }
    }

    func loadDrills() async {
        isLoadingDrills = true
        drillsError = nil
        do {
            drills = try await client.drills()
            cachedDrillsDate = nil
            OfflineCache.save(drills, key: drillsCacheKey)
        } catch {
            if let cached = OfflineCache.load([Drill].self, key: drillsCacheKey) {
                drills = cached.value
                cachedDrillsDate = cached.savedAt
            } else {
                drillsError = "Could not load drills: \(error.localizedDescription)"
            }
        }
        isLoadingDrills = false
    }

    func loadRecommendations() async {
        guard !isLoadingRecommendations else { return }
        isLoadingRecommendations = true
        recommendationsError = nil
        // Capture the choice this request is for: the player can change it
        // while the request is out, and the cache entry must match the
        // request that was sent, not whatever is selected on return.
        let requestID = recommendationsRequestID
        let company = trainingCompany
        let cacheKey = recommendationsCacheKey(for: company)
        do {
            var fetched = try await client.recommendations(playersAvailable: company.rawValue)
            guard requestID == recommendationsRequestID else { return }
            cachedRecommendationsDate = nil
            OfflineCache.save(fetched, key: cacheKey)
            recommendationsSavedAt = Date()
            // The server only knows the player's DUPR; if they took the skill
            // check, lead with drills for their weakest categories.
            if let assessment = SkillAssessment.load() {
                fetched = SkillAssessment.rank(fetched, by: assessment)
            }
            recommendations = fetched
        } catch let error as PickleballTrainingGenieError {
            guard requestID == recommendationsRequestID else { return }
            recommendationsError = error.serverMessage ?? "Could not load recommendations."
            cachedRecommendationsDate = recommendationsSavedAt
        } catch {
            guard requestID == recommendationsRequestID else { return }
            // Plain network failure — fall back to the last good fetch for
            // this same choice.
            if let cached = OfflineCache.load([Drill].self, key: cacheKey) {
                var fetched = cached.value
                if let assessment = SkillAssessment.load() {
                    fetched = SkillAssessment.rank(fetched, by: assessment)
                }
                recommendations = fetched
                cachedRecommendationsDate = cached.savedAt
                recommendationsSavedAt = cached.savedAt
            } else {
                recommendationsError = "Could not load recommendations: \(error.localizedDescription)"
            }
            AppLog.network.error("Recommendation refresh failed: \(error.localizedDescription)")
        }
        isLoadingRecommendations = false
    }

    /// Forgets the recommendations and anything about where they came from.
    /// Any fetch still in flight sees the bumped request id and discards its
    /// result, so `isLoadingRecommendations` is reset here and the next
    /// screen to appear can start a fresh fetch straight away.
    private func invalidateRecommendations() {
        recommendationsRequestID += 1
        recommendations = []
        recommendationsError = nil
        cachedRecommendationsDate = nil
        recommendationsSavedAt = nil
        isLoadingRecommendations = false
    }

    func completeDrill(id: String) async {
        do {
            _ = try await client.completeDrill(id: id)
            completedDrillIds.insert(id)
        } catch {
            // API call failed; do not mark as completed
        }
    }

    /// Seeds completedDrillIds from the server so completions survive app restarts.
    func loadDrillProgress() async {
        do {
            let progress = try await client.drillProgress()
            completedDrillIds.formUnion(progress.map(\.drillId))
        } catch {
            // Non-critical; completions just won't be pre-checked this launch.
        }
    }

    /// Records the current workout plan as a completed session, marking which
    /// drills (by index) the user actually finished, with optional per-drill
    /// self-ratings (1–5) and a journal note.
    func completeWorkout(
        completedIndices: Set<Int>,
        ratings: [Int: Int] = [:],
        notes: String? = nil
    ) async {
        guard let workout, !isCompletingWorkout else { return }
        isCompletingWorkout = true
        workoutCompletedSuccessfully = false
        workoutError = nil
        let drills = workout.drills.enumerated().map { index, item in
            WorkoutSessionDrillPayload(
                title: item.title,
                category: item.category,
                durationMinutes: item.durationMinutes,
                coachingNotes: item.coachingNotes,
                isCompleted: completedIndices.contains(index),
                selfRating: ratings[index]
            )
        }
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let request = CompleteWorkoutSessionRequest(
            durationMinutes: workout.totalDurationMinutes ?? workoutDuration,
            warmup: workout.warmup,
            cooldown: workout.cooldown,
            notes: (trimmedNotes?.isEmpty ?? true) ? nil : trimmedNotes,
            drills: drills
        )
        do {
            _ = try await client.completeWorkoutSession(request)
            workoutCompletedSuccessfully = true
            self.workout = nil
            completedWorkoutDrillIndices = []
            cachedWorkoutDate = nil
            OfflineCache.remove(key: workoutCacheKey)
            trainingStreakStore?.refreshAfterSave()
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code, _) where code == 404:
                workoutError = "The server doesn't support workout history yet."
            default:
                workoutError = "Could not save your workout. Please try again."
            }
        } catch {
            workoutError = "Could not save your workout: \(error.localizedDescription)"
        }
        isCompletingWorkout = false
    }

    func generateWorkout() async {
        isGeneratingWorkout = true
        workoutError = nil
        // The old plan (possibly restored from cache) is only replaced on
        // success — a failed generate at the court must not cost the player
        // the workout they already had.
        do {
            workout = try await client.generateWorkout(
                durationMinutes: workoutDuration,
                playersAvailable: trainingCompany.rawValue
            )
            completedWorkoutDrillIndices = []
            cachedWorkoutDate = nil
            if let workout {
                OfflineCache.save(workout, key: workoutCacheKey)
            }
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code, _) where code == 401:
                workoutError = "Please log in to generate a personalized workout."
            case .invalidResponse(let code, _) where code == 400:
                // The server explains what to change (e.g. no solo drills in
                // range yet — try "With a partner"); pass that straight through.
                workoutError = error.serverMessage ?? "Could not generate workout. Please try again."
            default:
                workoutError = "Could not generate workout. Please try again."
            }
        } catch {
            workoutError = "Could not generate workout: \(error.localizedDescription)"
        }
        isGeneratingWorkout = false
    }
}
