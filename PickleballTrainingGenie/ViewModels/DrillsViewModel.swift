import Foundation
import SwiftUI

@MainActor
class DrillsViewModel: ObservableObject {
    @Published var drills: [Drill] = []
    @Published var recommendations: [Drill] = []
    @Published var workout: WorkoutPlanResponse?
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
    /// workout to another.
    private let drillsCacheKey = "drills"
    private let recommendationsCacheKey: String
    private let workoutCacheKey: String

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

    init(client: PickleballTrainingGenieClient, userId: String? = nil) {
        self.client = client
        let scope = userId.map { "-\($0)" } ?? ""
        recommendationsCacheKey = "recommendations\(scope)"
        workoutCacheKey = "currentWorkout\(scope)"
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
        isLoadingRecommendations = true
        recommendationsError = nil
        do {
            var fetched = try await client.recommendations()
            cachedRecommendationsDate = nil
            OfflineCache.save(fetched, key: recommendationsCacheKey)
            // The server only knows the player's DUPR; if they took the skill
            // check, lead with drills for their weakest categories.
            if let assessment = SkillAssessment.load() {
                fetched = SkillAssessment.rank(fetched, by: assessment)
            }
            recommendations = fetched
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 401:
                recommendationsError = "Please log in to see your recommendations."
            default:
                recommendationsError = "Could not load recommendations."
            }
        } catch {
            // Plain network failure — fall back to the last good fetch.
            if let cached = OfflineCache.load([Drill].self, key: recommendationsCacheKey) {
                var fetched = cached.value
                if let assessment = SkillAssessment.load() {
                    fetched = SkillAssessment.rank(fetched, by: assessment)
                }
                recommendations = fetched
                cachedRecommendationsDate = cached.savedAt
            } else {
                recommendationsError = "Could not load recommendations: \(error.localizedDescription)"
            }
        }
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
    /// drills (by index) the user actually finished.
    func completeWorkout(completedIndices: Set<Int>) async {
        guard let workout else { return }
        isCompletingWorkout = true
        workoutError = nil
        let drills = workout.drills.enumerated().map { index, item in
            WorkoutSessionDrillPayload(
                title: item.title,
                category: item.category,
                durationMinutes: item.durationMinutes,
                coachingNotes: item.coachingNotes,
                isCompleted: completedIndices.contains(index)
            )
        }
        let request = CompleteWorkoutSessionRequest(
            durationMinutes: workout.totalDurationMinutes ?? workoutDuration,
            warmup: workout.warmup,
            cooldown: workout.cooldown,
            drills: drills
        )
        do {
            _ = try await client.completeWorkoutSession(request)
            workoutCompletedSuccessfully = true
            self.workout = nil
            cachedWorkoutDate = nil
            OfflineCache.remove(key: workoutCacheKey)
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 404:
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
            workout = try await client.generateWorkout(durationMinutes: workoutDuration)
            cachedWorkoutDate = nil
            if let workout {
                OfflineCache.save(workout, key: workoutCacheKey)
            }
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 401:
                workoutError = "Please log in to generate a personalized workout."
            default:
                workoutError = "Could not generate workout. Please try again."
            }
        } catch {
            workoutError = "Could not generate workout: \(error.localizedDescription)"
        }
        isGeneratingWorkout = false
    }
}
