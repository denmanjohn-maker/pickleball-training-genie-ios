import Foundation
import SwiftUI
import AuthenticationServices

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
        // Restore saved token on launch from Keychain
        if let savedToken = KeychainHelper.read(forKey: "jwtToken"),
           !savedToken.isEmpty {
            client.jwtToken = savedToken
            isAuthenticated = true
            Task {
                await fetchProfile()
            }
        }
    }

    func fetchProfile() async {
        do {
            currentUser = try await client.getProfile()
        } catch {
            print("Failed to fetch profile: \(error)")
            // Optionally handle token expiration by logging out
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await client.login(email: email, password: password)
            KeychainHelper.save(response.token, forKey: "jwtToken")
            isAuthenticated = true
            await fetchProfile()
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 401:
                errorMessage = "Invalid email or password."
            case .invalidResponse(let code) where code == 0:
                errorMessage = connectionErrorMessage()
            case .invalidResponse(let code):
                errorMessage = "Login failed (error \(code))."
            case .invalidURL:
                errorMessage = "Invalid server configuration."
            }
        } catch let error as URLError {
            errorMessage = networkErrorMessage(for: error)
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func loginWithDUPR(presentationContextProvider: ASWebAuthenticationPresentationContextProviding) async {
        isLoading = true
        errorMessage = nil
        
        // Setup DUPR OAuth
        let authURL = URL(string: "https://mydupr.com/oauth/authorize?client_id=YOUR_CLIENT_ID&redirect_uri=pickleballgenie://oauth2/callback&response_type=code")!
        let callbackScheme = "pickleballgenie"
        
        do {
            let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: callbackScheme) { url, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let url = url {
                        continuation.resume(returning: url)
                    }
                }
                session.presentationContextProvider = presentationContextProvider
                session.start()
            }
            
            guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                throw URLError(.badURL)
            }
            
            let response = try await client.loginWithDUPR(authCode: code)
            KeychainHelper.save(response.token, forKey: "jwtToken")
            isAuthenticated = true
            await fetchProfile()
        } catch {
            if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
                // User canceled, no error message needed
            } else {
                errorMessage = "DUPR login failed: \(error.localizedDescription)"
            }
        }
        isLoading = false
    }

    func updateRatings(singles: Decimal?, doubles: Decimal?) async {
        isLoading = true
        errorMessage = nil
        do {
            let updatedUser = try await client.updateRatings(singlesDUPR: singles, doublesDUPR: doubles)
            self.currentUser = updatedUser
        } catch {
            errorMessage = "Failed to update ratings: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func register(
        email: String,
        password: String,
        singlesDUPR: Decimal?,
        doublesDUPR: Decimal?,
        targetDUPR: Decimal
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await client.register(
                email: email,
                password: password,
                singlesDUPR: singlesDUPR,
                doublesDUPR: doublesDUPR,
                targetDUPR: targetDUPR
            )
            isLoading = false
            return true
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 400:
                errorMessage = "Registration failed. This email may already be in use."
            case .invalidResponse(let code) where code == 0:
                errorMessage = connectionErrorMessage()
            case .invalidResponse(let code):
                errorMessage = "Registration failed (error \(code))."
            case .invalidURL:
                errorMessage = "Invalid server configuration."
            }
        } catch let error as URLError {
            errorMessage = networkErrorMessage(for: error)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        return false
    }

    func logout() {
        KeychainHelper.delete(forKey: "jwtToken")
        client.jwtToken = nil
        isAuthenticated = false
        currentUser = nil
    }

    private func networkErrorMessage(for error: URLError) -> String {
        switch error.code {
        case .cannotFindHost, .cannotConnectToHost, .timedOut, .networkConnectionLost, .notConnectedToInternet:
            return connectionErrorMessage()
        default:
            return "Network error: \(error.localizedDescription)"
        }
    }

    private func connectionErrorMessage() -> String {
        let url = client.baseURL.absoluteString
        if url.contains("localhost") || url.contains("127.0.0.1") {
            return "Cannot reach \(url). Use http://localhost:5123/ for dotnet run or http://localhost:8080/ for Docker. On a physical device, set API_BASE_URL to your Mac's local IP instead of localhost."
        }
        return "Cannot reach \(url). Make sure the hosted API is available or override API_BASE_URL for your local backend."
    }
}

enum APIConfig {
    static let baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"]
        ?? "https://thepickleballgenie.com/"
}
import Foundation
import AuthenticationServices
import UIKit

class AuthenticationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
    }
}
