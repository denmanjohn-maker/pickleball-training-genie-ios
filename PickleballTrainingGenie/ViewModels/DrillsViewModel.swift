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

    let drillCategories = [
        "Dinking", "Drops", "Volleys", "Serving", "Returns",
        "Lobs", "Resets", "Attacking", "Movement", "General"
    ]

    let duprLevels: [Decimal] = [3.0, 3.5, 4.0, 5.0]

    var filteredDrills: [Drill] {
        drills.filter { drill in
            let categoryMatch = selectedCategory == nil || drill.category == selectedCategory
            let levelMatch = selectedLevel == nil || drill.targetDUPRLevel == selectedLevel
            return categoryMatch && levelMatch
        }
    }

    private let client: PickleballTrainingGenieClient

    init(client: PickleballTrainingGenieClient) {
        self.client = client
    }

    func loadDrills() async {
        isLoadingDrills = true
        drillsError = nil
        do {
            drills = try await client.drills()
        } catch {
            drillsError = "Could not load drills: \(error.localizedDescription)"
        }
        isLoadingDrills = false
    }

    func loadRecommendations() async {
        isLoadingRecommendations = true
        recommendationsError = nil
        do {
            recommendations = try await client.recommendations()
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 401:
                recommendationsError = "Please log in to see your recommendations."
            default:
                recommendationsError = "Could not load recommendations."
            }
        } catch {
            recommendationsError = "Could not load recommendations: \(error.localizedDescription)"
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
        workout = nil
        do {
            workout = try await client.generateWorkout(durationMinutes: workoutDuration)
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
