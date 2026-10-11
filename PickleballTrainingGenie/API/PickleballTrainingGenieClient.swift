import Foundation

struct HealthResponse: Codable, Equatable, Sendable {
    let status: String
}

struct Drill: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let targetDUPRLevel: Decimal
    let category: String
    let videoUrl: String?
    let sourceUrl: String
    let createdAt: String
}

struct User: Codable, Equatable, Sendable {
    let id: String
    let email: String
    let firstName: String?
    let lastName: String?
    let zipCode: String?
    let homeCityId: Int?
    let homeCityName: String?
    let dominantHand: String?
    let yearsPlaying: Int?
    let preferredPlayStyle: String?
    let avatarId: String?
    let singlesDUPR: Decimal?
    let doublesDUPR: Decimal?
    let isDuprLinked: Bool
    let preferredSessionDurationMinutes: Int?
    let targetDUPR: Decimal
    // Optional so the app still works against a backend that predates profiles.
    let isProfileComplete: Bool?
    let hasCustomAvatar: Bool?

    var displayName: String {
        let name = [firstName, lastName].compactMap { $0 }.joined(separator: " ")
        return name.isEmpty ? email : name
    }

    var needsOnboarding: Bool { !(isProfileComplete ?? true) }
}

struct LoginResponse: Codable, Equatable, Sendable {
    let token: String
    let isProfileComplete: Bool?
}

struct UpdateProfileRequest: Encodable, Sendable {
    var firstName: String?
    var lastName: String?
    var zipCode: String?
    var homeCityId: Int?
    var homeCityName: String?
    var dominantHand: String?
    var yearsPlaying: Int?
    var preferredPlayStyle: String?
    var avatarId: String?
    // Doubles (not Decimal) so JSONEncoder emits clean values like 3.5.
    var singlesDUPR: Double?
    var doublesDUPR: Double?
    var targetDUPR: Double?
    var preferredSessionDurationMinutes: Int?
}

struct WorkoutSessionDrillPayload: Codable, Identifiable, Sendable {
    let title: String
    let category: String
    let durationMinutes: Int
    let coachingNotes: String?
    let isCompleted: Bool
    /// 1 (struggled) … 5 (nailed it); nil when the player didn't rate.
    /// Optional so decoding stays compatible with backends that predate it.
    var selfRating: Int?

    var id: String { title }
}

struct CompleteWorkoutSessionRequest: Encodable, Sendable {
    let durationMinutes: Int
    let warmup: String?
    let cooldown: String?
    /// Free-form journal note. Optional; older backends ignore unknown fields.
    let notes: String?
    let drills: [WorkoutSessionDrillPayload]
}

struct WorkoutSessionResponse: Codable, Identifiable, Sendable {
    let id: String
    let completedAt: String
    let durationMinutes: Int
    let warmup: String?
    let cooldown: String?
    let notes: String?
    let drills: [WorkoutSessionDrillPayload]
}

struct WorkoutSessionListResponse: Codable, Sendable {
    let items: [WorkoutSessionResponse]
    let totalCount: Int
    let page: Int
    let pageSize: Int
}

struct DrillProgressItem: Codable, Identifiable, Sendable {
    let drillId: String
    let title: String
    let category: String
    let status: String
    let completedAt: String?

    var id: String { drillId }
}

struct MessageResponse: Codable, Equatable, Sendable {
    let message: String
}

struct GenerateWorkoutRequest: Codable, Sendable {
    let durationMinutes: Int?
}

struct WorkoutDrillItem: Codable, Identifiable, Sendable, Equatable {
    let title: String
    let category: String
    let durationMinutes: Int
    let coachingNotes: String

    var id: String { title }
}

struct WorkoutPlanResponse: Codable, Sendable {
    let warmup: String?
    let drills: [WorkoutDrillItem]
    let cooldown: String?
    let totalDurationMinutes: Int?
    let rawResponse: String?

    enum CodingKeys: String, CodingKey {
        case warmup, drills, cooldown, rawResponse
        case totalDurationMinutes = "totalDuration"
    }
}

// MARK: - Error type

/// Error thrown by `PickleballTrainingGenieClient`.
///
/// `serverMessage` carries the human-readable text from the backend's error body
/// (ASP.NET `ProblemDetails`, `{ "message": … }`, or plain text) so a 400 can say
/// "Email is already in use." instead of "error 400". It's `nil` when the
/// server sent nothing useful.
enum PickleballTrainingGenieError: Error, Equatable {
    case invalidURL
    /// Non-2xx response. `statusCode` is 0 when no HTTP response arrived at all.
    case invalidResponse(statusCode: Int, serverMessage: String? = nil)

    var statusCode: Int? {
        if case .invalidResponse(let code, _) = self { return code }
        return nil
    }

    var serverMessage: String? {
        if case .invalidResponse(_, let message) = self { return message }
        return nil
    }
}

extension PickleballTrainingGenieError: LocalizedError {
    /// Lets the many `error.localizedDescription` call sites in the view models
    /// show the server's own explanation when there is one.
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server configuration."
        case .invalidResponse(let code, let message):
            if let message, !message.isEmpty { return message }
            switch code {
            case 0: return "The server did not respond."
            case 401: return "Your session has expired. Please sign in again."
            case 404: return "This feature isn't available on the server yet."
            case 500...599: return "The server hit a problem (error \(code)). Please try again."
            default: return "The server returned an error (\(code))."
            }
        }
    }
}

/// Extracts a user-facing message from an HTTP error body.
enum ServerErrorBody {
    /// Shape shared by ASP.NET `ProblemDetails` / `ValidationProblemDetails`
    /// and the API's own `{ "message": … }` responses. Every field optional.
    private struct Body: Decodable {
        let title: String?
        let detail: String?
        let message: String?
        let errors: [String: [String]]?
    }

    static func message(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let body = try? JSONDecoder().decode(Body.self, from: data) {
            if let errors = body.errors, !errors.isEmpty {
                // Field errors, sorted by field so the order is stable.
                let lines = errors.sorted { $0.key < $1.key }
                    .flatMap(\.value)
                    .compactMap { clean($0) }
                if !lines.isEmpty { return lines.joined(separator: " ") }
            }
            return clean(body.detail) ?? clean(body.message) ?? clean(body.title)
        }
        // A bare JSON string, e.g. "Email already registered".
        if let text = try? JSONDecoder().decode(String.self, from: data) {
            return clean(text)
        }
        // Plain text — but never an HTML error page or a stack trace.
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 300,
              !trimmed.hasPrefix("<"), !trimmed.hasPrefix("{"), !trimmed.hasPrefix("[") else { return nil }
        return trimmed
    }

    private static func clean(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

// MARK: - JWT inspection

/// Reads the `exp` claim out of a JWT without verifying it. Verification is the
/// server's job; the client only wants to know whether a saved token is already
/// dead so it can go straight to sign-in instead of failing its first request.
enum JWTClaims {
    static func expirationDate(of token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = object["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    /// `false` when the token has no readable `exp` — the server decides then.
    static func isExpired(_ token: String, now: Date = Date(), leeway: TimeInterval = 30) -> Bool {
        guard let expiry = expirationDate(of: token) else { return false }
        return expiry.addingTimeInterval(-leeway) <= now
    }
}

// MARK: - Client

class PickleballTrainingGenieClient {
    let baseURL: URL
    let session: URLSession
    var jwtToken: String?
    /// Fired when an *authenticated* request is rejected with 401 — the token is
    /// dead and the app should return to sign-in. Not fired for login attempts,
    /// where 401 just means wrong credentials. Called off the main thread.
    var onUnauthorized: (@Sendable () -> Void)?

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// Courts have bad signal: fail fast so the view models can fall back to
    /// the offline cache instead of hanging on the 60-second system default.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    init(baseURL: URL, session: URLSession = PickleballTrainingGenieClient.makeSession()) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: Auth

    func login(email: String, password: String) async throws -> LoginResponse {
        let response: LoginResponse = try await send(
            jsonRequest(path: "api/Users/login", method: "POST", body: ["email": email, "password": password]),
            requireAuth: false
        )
        self.jwtToken = response.token
        return response
    }

    func register(
        email: String,
        password: String,
        singlesDUPR: Decimal?,
        doublesDUPR: Decimal?,
        targetDUPR: Decimal
    ) async throws -> MessageResponse {
        var payload: [String: Any] = [
            "email": email,
            "password": password,
            "targetDUPR": NSDecimalNumber(decimal: targetDUPR).doubleValue
        ]
        if let singles = singlesDUPR {
            payload["singlesDUPR"] = NSDecimalNumber(decimal: singles).doubleValue
        }
        if let doubles = doublesDUPR {
            payload["doublesDUPR"] = NSDecimalNumber(decimal: doubles).doubleValue
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        return try await send(
            request(path: "api/Users/register", method: "POST", body: data, contentType: "application/json"),
            requireAuth: false
        )
    }

    func googleLogin(idToken: String) async throws -> LoginResponse {
        let response: LoginResponse = try await send(
            jsonRequest(path: "api/Users/google-login", method: "POST", body: ["idToken": idToken]),
            requireAuth: false
        )
        self.jwtToken = response.token
        return response
    }

    func appleLogin(identityToken: String, firstName: String?, lastName: String?) async throws -> LoginResponse {
        var payload = ["identityToken": identityToken]
        if let firstName { payload["firstName"] = firstName }
        if let lastName { payload["lastName"] = lastName }
        let response: LoginResponse = try await send(
            jsonRequest(path: "api/Users/apple-login", method: "POST", body: payload),
            requireAuth: false
        )
        self.jwtToken = response.token
        return response
    }

    // MARK: Profile

    func getProfile() async throws -> User {
        try await send(request(path: "api/Users/profile", method: "GET"), requireAuth: true)
    }

    func updateRatings(singlesDUPR: Decimal?, doublesDUPR: Decimal?, targetDUPR: Decimal? = nil) async throws -> User {
        struct UpdateRatingsRequest: Encodable {
            let singlesDUPR: Decimal?
            let doublesDUPR: Decimal?
            let targetDUPR: Decimal?
        }
        let payload = UpdateRatingsRequest(singlesDUPR: singlesDUPR, doublesDUPR: doublesDUPR, targetDUPR: targetDUPR)
        return try await send(
            jsonRequest(path: "api/Users/profile/ratings", method: "PUT", body: payload),
            requireAuth: true
        )
    }

    func updateProfile(_ profile: UpdateProfileRequest) async throws -> User {
        try await send(
            jsonRequest(path: "api/Users/profile", method: "PUT", body: profile),
            requireAuth: true
        )
    }

    func uploadAvatar(imageData: Data, contentType: String = "image/jpeg") async throws -> User {
        try await send(
            request(path: "api/Users/profile/avatar", method: "POST", body: imageData, contentType: contentType),
            requireAuth: true
        )
    }

    /// Returns the user's custom avatar image bytes, or nil if none is set.
    func fetchAvatarData() async throws -> Data? {
        do {
            let (data, _) = try await perform(request(path: "api/Users/profile/avatar", method: "GET"), requireAuth: true)
            return data
        } catch let error as PickleballTrainingGenieError where error.statusCode == 404 {
            return nil
        }
    }

    func deleteAvatar() async throws -> User {
        try await send(request(path: "api/Users/profile/avatar", method: "DELETE"), requireAuth: true)
    }

    /// Permanently deletes the authenticated user's account and all associated
    /// data. A deleted account returns no user JSON (e.g. 204 No Content), so
    /// only the status code is checked.
    func deleteAccount() async throws {
        _ = try await perform(request(path: "api/Users/profile", method: "DELETE"), requireAuth: true)
    }

    // MARK: Workouts

    func completeWorkoutSession(_ session: CompleteWorkoutSessionRequest) async throws -> WorkoutSessionResponse {
        try await send(
            jsonRequest(path: "api/Workouts/sessions", method: "POST", body: session),
            requireAuth: true
        )
    }

    func workoutSessions(page: Int = 1, pageSize: Int = 20) async throws -> WorkoutSessionListResponse {
        var components = try urlComponents(path: "api/Workouts/sessions")
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
        guard let url = components.url else { throw PickleballTrainingGenieError.invalidURL }
        return try await send(request(url: url, method: "GET"), requireAuth: true)
    }

    func generateWorkout(durationMinutes: Int? = nil) async throws -> WorkoutPlanResponse {
        // AI generation is the one slow call; give it more room than the
        // session default without letting it hang forever.
        var requestObj = try jsonRequest(
            path: "api/workouts/generate",
            method: "POST",
            body: GenerateWorkoutRequest(durationMinutes: durationMinutes)
        )
        requestObj.timeoutInterval = 90
        return try await send(requestObj, requireAuth: true)
    }

    // MARK: Drills

    func drillProgress() async throws -> [DrillProgressItem] {
        try await send(request(path: "api/Drills/progress", method: "GET"), requireAuth: true)
    }

    func drills(category: String? = nil, level: Decimal? = nil) async throws -> [Drill] {
        var components = try urlComponents(path: "api/Drills")
        var queryItems: [URLQueryItem] = []
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let level = level {
            queryItems.append(URLQueryItem(
                name: "level",
                value: NSDecimalNumber(decimal: level).stringValue
            ))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else { throw PickleballTrainingGenieError.invalidURL }
        return try await send(request(url: url, method: "GET"), requireAuth: false)
    }

    func recommendations() async throws -> [Drill] {
        try await send(request(path: "api/Drills/recommendations", method: "GET"), requireAuth: true)
    }

    func completeDrill(id: String) async throws -> MessageResponse {
        try await send(
            jsonRequest(path: "api/Drills/\(id)/complete", method: "POST", body: [String: String]()),
            requireAuth: true
        )
    }

    // MARK: Plumbing

    func urlComponents(path: String) throws -> URLComponents {
        guard let components = URLComponents(url: url(path: path), resolvingAgainstBaseURL: false) else {
            throw PickleballTrainingGenieError.invalidURL
        }
        return components
    }

    private func url(path: String) -> URL {
        baseURL.appending(path: path)
    }

    private func request(path: String, method: String, body: Data? = nil, contentType: String? = nil) -> URLRequest {
        request(url: url(path: path), method: method, body: body, contentType: contentType)
    }

    private func request(url: URL, method: String, body: Data? = nil, contentType: String? = nil) -> URLRequest {
        var requestObj = URLRequest(url: url)
        requestObj.httpMethod = method
        requestObj.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            requestObj.httpBody = body
            requestObj.setValue(contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
        }
        return requestObj
    }

    private func jsonRequest<Body: Encodable>(path: String, method: String, body: Body) throws -> URLRequest {
        request(path: path, method: method, body: try encoder.encode(body), contentType: "application/json")
    }

    /// Sends the request, attaching the bearer token when `requireAuth`, and
    /// turns any non-2xx status into `PickleballTrainingGenieError` with the
    /// server's message. A 401 on an authenticated call also fires
    /// `onUnauthorized` so the app can return to sign-in.
    private func perform(_ requestObj: URLRequest, requireAuth: Bool) async throws -> (Data, HTTPURLResponse) {
        var requestObj = requestObj
        if requireAuth, let token = jwtToken {
            requestObj.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let method = requestObj.httpMethod ?? "GET"
        let path = requestObj.url?.path ?? ""
        let (data, response) = try await session.data(for: requestObj)
        guard let httpResponse = response as? HTTPURLResponse else {
            AppLog.network.error("\(method, privacy: .public) \(path, privacy: .public) → no HTTP response")
            throw PickleballTrainingGenieError.invalidResponse(statusCode: 0)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let message = ServerErrorBody.message(from: data)
            AppLog.network.error(
                "\(method, privacy: .public) \(path, privacy: .public) → \(httpResponse.statusCode, privacy: .public) \(message ?? "", privacy: .public)"
            )
            if httpResponse.statusCode == 401, requireAuth, jwtToken != nil {
                onUnauthorized?()
            }
            throw PickleballTrainingGenieError.invalidResponse(statusCode: httpResponse.statusCode, serverMessage: message)
        }
        AppLog.network.debug("\(method, privacy: .public) \(path, privacy: .public) → \(httpResponse.statusCode, privacy: .public)")
        return (data, httpResponse)
    }

    private func send<Response: Decodable>(_ requestObj: URLRequest, requireAuth: Bool) async throws -> Response {
        let (data, _) = try await perform(requestObj, requireAuth: requireAuth)
        return try decoder.decode(Response.self, from: data)
    }
}
