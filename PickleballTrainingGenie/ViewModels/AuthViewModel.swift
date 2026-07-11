import Foundation
import SwiftUI
import UIKit
import AuthenticationServices
import GoogleSignIn

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var profileLoadFailed = false
    /// Cached custom avatar photo. AsyncImage can't send the bearer header,
    /// so the image is fetched through the API client and held here.
    @Published var avatarImage: UIImage?

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
        profileLoadFailed = false
        do {
            currentUser = try await client.getProfile()
            await loadAvatarIfNeeded()
        } catch let error as PickleballTrainingGenieError {
            if case .invalidResponse(let code) = error, code == 401 {
                // Token expired — force a fresh sign-in instead of spinning.
                logout()
                return
            }
            print("Failed to fetch profile: \(error)")
            profileLoadFailed = true
        } catch {
            print("Failed to fetch profile: \(error)")
            profileLoadFailed = true
        }
    }

    func loadAvatarIfNeeded() async {
        guard currentUser?.hasCustomAvatar == true else {
            if currentUser?.avatarId != "custom" { avatarImage = nil }
            return
        }
        guard avatarImage == nil else { return }
        if let data = try? await client.fetchAvatarData(), let image = UIImage(data: data) {
            avatarImage = image
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response = try await client.login(email: email, password: password)
            completeSignIn(token: response.token)
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

    // MARK: - Social sign-in

    var isGoogleSignInConfigured: Bool {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            return false
        }
        return !clientID.isEmpty && !clientID.hasPrefix("YOUR_")
    }

    func signInWithGoogle() async {
        errorMessage = nil
        guard isGoogleSignInConfigured else {
            errorMessage = "Google Sign-In isn't configured yet. Add your GIDClientID to Info.plist."
            return
        }
        guard let presenter = Self.topViewController() else {
            errorMessage = "Could not present Google Sign-In."
            return
        }
        isLoading = true
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google did not return an ID token."
                isLoading = false
                return
            }
            let response = try await client.googleLogin(idToken: idToken)
            completeSignIn(token: response.token)
            await fetchProfile()
        } catch let error as GIDSignInError where error.code == .canceled {
            // User dismissed the sheet — not an error.
        } catch let error as PickleballTrainingGenieError {
            switch error {
            case .invalidResponse(let code) where code == 401:
                errorMessage = "Google sign-in was rejected by the server."
            case .invalidResponse(let code) where code == 404:
                errorMessage = "The server doesn't support Google sign-in yet."
            case .invalidResponse(let code) where code == 0:
                errorMessage = connectionErrorMessage()
            case .invalidResponse(let code):
                errorMessage = "Google sign-in failed (error \(code))."
            case .invalidURL:
                errorMessage = "Invalid server configuration."
            }
        } catch {
            errorMessage = "Google sign-in failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                return
            }
            errorMessage = "Apple sign-in failed: \(error.localizedDescription)"
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple did not return an identity token."
                return
            }
            isLoading = true
            do {
                // Apple only provides the name on the very first authorization.
                let response = try await client.appleLogin(
                    identityToken: identityToken,
                    firstName: credential.fullName?.givenName,
                    lastName: credential.fullName?.familyName
                )
                completeSignIn(token: response.token)
                await fetchProfile()
            } catch let error as PickleballTrainingGenieError {
                switch error {
                case .invalidResponse(let code) where code == 401:
                    errorMessage = "Apple sign-in was rejected by the server."
                case .invalidResponse(let code) where code == 404:
                    errorMessage = "The server doesn't support Apple sign-in yet."
                case .invalidResponse(let code) where code == 0:
                    errorMessage = connectionErrorMessage()
                case .invalidResponse(let code):
                    errorMessage = "Apple sign-in failed (error \(code))."
                case .invalidURL:
                    errorMessage = "Invalid server configuration."
                }
            } catch {
                errorMessage = "Apple sign-in failed: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func completeSignIn(token: String) {
        KeychainHelper.save(token, forKey: "jwtToken")
        isAuthenticated = true
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let root = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    func updateRatings(singles: Decimal?, doubles: Decimal?, target: Decimal? = nil) async {
        isLoading = true
        errorMessage = nil
        do {
            let updatedUser = try await client.updateRatings(singlesDUPR: singles, doublesDUPR: doubles, targetDUPR: target)
            self.currentUser = updatedUser
        } catch {
            errorMessage = "Failed to update ratings: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func updateProfile(_ request: UpdateProfileRequest) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let updatedUser = try await client.updateProfile(request)
            self.currentUser = updatedUser
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    func uploadAvatarPhoto(_ jpegData: Data) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let updatedUser = try await client.uploadAvatar(imageData: jpegData)
            self.currentUser = updatedUser
            self.avatarImage = UIImage(data: jpegData)
            isLoading = false
            return true
        } catch {
            errorMessage = "Failed to upload photo: \(error.localizedDescription)"
            isLoading = false
            return false
        }
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
        GIDSignIn.sharedInstance.signOut()
        isAuthenticated = false
        currentUser = nil
        avatarImage = nil
        profileLoadFailed = false
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
