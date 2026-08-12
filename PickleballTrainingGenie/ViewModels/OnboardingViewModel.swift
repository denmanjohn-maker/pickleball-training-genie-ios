import Foundation
import SwiftUI
import UIKit

/// Drives the profile-completion onboarding flow shown to any authenticated user
/// whose profile is missing required fields (fresh signups, Google/Apple sign-ins,
/// and existing accounts created before profiles existed).
@MainActor
class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case name
        case ratings
        case preferences
        case avatar

        var title: String {
            switch self {
            case .name: return "About You"
            case .ratings: return "Your DUPR"
            case .preferences: return "Preferences"
            case .avatar: return "Pick an Avatar"
            }
        }
    }

    @Published var step: Step = .name

    // Step 1 — name + location
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var zipCode = "" {
        didSet { zipCodeChanged() }
    }
    @Published var matchedCity: City?
    @Published var cities: [City] = []
    @Published var isLoadingCities = false
    @Published var citiesError: String?

    // Step 2 — ratings
    @Published var singlesDUPR: Decimal = 3.0
    @Published var doublesDUPR: Decimal = 3.0
    @Published var targetDUPR: Decimal = 3.5

    // Step 3 — optional preferences
    @Published var sessionDuration = 30
    @Published var dominantHand = "right"
    @Published var playStyle = "both"
    @Published var yearsPlaying = 1

    // Step 4 — avatar
    @Published var selectedAvatar: BuiltInAvatar? = .paddlePro
    @Published var customPhotoData: Data?
    @Published var customPhotoImage: UIImage?

    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let tournamentsClient: TournamentsAPIClient

    init(tournamentsClient: TournamentsAPIClient = TournamentsAPIClient(baseURL: URL(string: TournamentsAPIConfig.baseURL)!)) {
        self.tournamentsClient = tournamentsClient
    }

    var zipValid: Bool { ZipCityMatcher.isValidZip(zipCode) }

    var nameStepValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && zipValid
    }

    var targetValid: Bool { targetDUPR >= max(singlesDUPR, doublesDUPR) }

    /// Adopts the skill-check estimate: both ratings start at the estimated
    /// level, with the target one tier up.
    func apply(assessment result: AssessmentResult) {
        let suggested = result.suggestedRatings
        singlesDUPR = suggested.singles
        doublesDUPR = suggested.doubles
        targetDUPR = suggested.target
    }

    func prefill(from user: User?) {
        guard let user else { return }
        if firstName.isEmpty, let name = user.firstName { firstName = name }
        if lastName.isEmpty, let name = user.lastName { lastName = name }
        if zipCode.isEmpty, let zip = user.zipCode { zipCode = zip }
        if let singles = user.singlesDUPR { singlesDUPR = singles }
        if let doubles = user.doublesDUPR { doublesDUPR = doubles }
        if user.targetDUPR > 0 { targetDUPR = max(user.targetDUPR, max(singlesDUPR, doublesDUPR)) }
        if let duration = user.preferredSessionDurationMinutes { sessionDuration = duration }
        if let hand = user.dominantHand { dominantHand = hand }
        if let style = user.preferredPlayStyle { playStyle = style }
        if let years = user.yearsPlaying { yearsPlaying = years }
        if let builtIn = BuiltInAvatar.from(avatarId: user.avatarId) { selectedAvatar = builtIn }
    }

    func loadCities() async {
        guard cities.isEmpty else { return }
        isLoadingCities = true
        citiesError = nil
        do {
            cities = try await tournamentsClient.cities()
            matchCity()
        } catch {
            citiesError = "Couldn't load tournament cities. You can still continue — we'll match your city later."
        }
        isLoadingCities = false
    }

    func matchCity() {
        guard zipValid else {
            matchedCity = nil
            return
        }
        matchedCity = ZipCityMatcher.closestCity(toZip: zipCode, in: cities)
    }

    func selectCity(_ city: City) {
        matchedCity = city
    }

    private func zipCodeChanged() {
        if zipCode.count > 5 {
            zipCode = String(zipCode.prefix(5))
            return // didSet fires again with the trimmed value
        }
        matchCity()
    }

    func goBack() {
        if let previous = Step(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        }
    }

    /// Saves the whole profile, uploads the custom photo if one was chosen,
    /// and refreshes the auth session's user so the profile gate opens.
    func submit(authViewModel: AuthViewModel) async {
        isSubmitting = true
        errorMessage = nil

        let avatarId: String?
        if customPhotoData != nil {
            avatarId = "custom"
        } else {
            avatarId = selectedAvatar?.avatarId
        }

        let request = UpdateProfileRequest(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            zipCode: zipCode,
            homeCityId: matchedCity?.id,
            homeCityName: matchedCity.map { "\($0.name), \($0.state)" },
            dominantHand: dominantHand,
            yearsPlaying: yearsPlaying,
            preferredPlayStyle: playStyle,
            avatarId: avatarId,
            singlesDUPR: NSDecimalNumber(decimal: singlesDUPR).doubleValue,
            doublesDUPR: NSDecimalNumber(decimal: doublesDUPR).doubleValue,
            targetDUPR: NSDecimalNumber(decimal: targetDUPR).doubleValue,
            preferredSessionDurationMinutes: sessionDuration
        )

        do {
            var updatedUser = try await authViewModel.client.updateProfile(request)

            if let photoData = customPhotoData {
                updatedUser = try await authViewModel.client.uploadAvatar(imageData: photoData)
                authViewModel.avatarImage = customPhotoImage
            }

            // Default the Tournaments tab to the matched home city.
            if let city = matchedCity {
                UserDefaults.standard.set(city.id, forKey: "tournaments.lastCityId")
            }

            authViewModel.currentUser = updatedUser
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 400:
                errorMessage = "The server rejected the profile. Check your ratings and try again."
            case .invalidResponse(let code) where code == 401:
                errorMessage = "Your session expired. Please sign in again."
            case .invalidResponse(let code) where code == 404:
                errorMessage = "The server doesn't support profiles yet. Please update the backend."
            case .invalidResponse(let code):
                errorMessage = "Could not save your profile (error \(code))."
            case .invalidURL:
                errorMessage = "Invalid server configuration."
            }
        } catch {
            errorMessage = "Could not save your profile: \(error.localizedDescription)"
        }
        isSubmitting = false
    }
}
