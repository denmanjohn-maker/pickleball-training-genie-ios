import Foundation
import SwiftUI

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?

    let client: PickleballTrainingGenieClient

    init() {
        let baseURL = URL(string: APIConfig.baseURL)!
        client = PickleballTrainingGenieClient(baseURL: baseURL)
        // Restore saved token on launch
        if let savedToken = UserDefaults.standard.string(forKey: "jwtToken"),
           !savedToken.isEmpty {
            client.jwtToken = savedToken
            isAuthenticated = true
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await client.login(email: email, password: password)
            UserDefaults.standard.set(response.token, forKey: "jwtToken")
            isAuthenticated = true
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 401:
                errorMessage = "Invalid email or password."
            case .invalidResponse(let code) where code == 0:
                errorMessage = "Cannot connect to the server. Please check your connection."
            case .invalidResponse(let code):
                errorMessage = "Login failed (error \(code))."
            case .invalidURL:
                errorMessage = "Invalid server configuration."
            }
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func register(
        email: String,
        password: String,
        currentDUPR: Decimal,
        targetDUPR: Decimal
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await client.register(
                email: email,
                password: password,
                currentDUPR: currentDUPR,
                targetDUPR: targetDUPR
            )
            isLoading = false
            return true
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 400:
                errorMessage = "Registration failed. This email may already be in use."
            case .invalidResponse(let code) where code == 0:
                errorMessage = "Cannot connect to the server. Please check your connection."
            case .invalidResponse(let code):
                errorMessage = "Registration failed (error \(code))."
            case .invalidURL:
                errorMessage = "Invalid server configuration."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        return false
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: "jwtToken")
        client.jwtToken = nil
        isAuthenticated = false
        currentUser = nil
    }
}

enum APIConfig {
    static let baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"]
        ?? "http://localhost:5000/"
}
