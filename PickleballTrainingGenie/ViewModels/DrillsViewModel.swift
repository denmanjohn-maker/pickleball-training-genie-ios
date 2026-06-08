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
