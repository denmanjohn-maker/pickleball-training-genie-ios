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

class PickleballTrainingGenieClient {
    let baseURL: URL
    let session: URLSession
    var jwtToken: String?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func login(email: String, password: String) async throws -> LoginResponse {
            let payload = ["email": email, "password": password]
            let response: LoginResponse = try await request(
                url(path: "api/Users/login"),
                method: "POST",
                body: payload,
                requireAuth: false
            )
            self.jwtToken = response.token
            return response
        }

        func getProfile() async throws -> User {
                    return try await request(
                        url(path: "api/Users/profile"),
                        method: "GET",
                        requireAuth: true
                    )
                }

        func updateRatings(singlesDUPR: Decimal?, doublesDUPR: Decimal?, targetDUPR: Decimal? = nil) async throws -> User {
            struct UpdateRatingsRequest: Encodable {
                let singlesDUPR: Decimal?
                let doublesDUPR: Decimal?
                let targetDUPR: Decimal?
            }
            let payload = UpdateRatingsRequest(singlesDUPR: singlesDUPR, doublesDUPR: doublesDUPR, targetDUPR: targetDUPR)
            return try await request(
                url(path: "api/Users/profile/ratings"),
                method: "PUT",
                body: payload,
                requireAuth: true
            )
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
        var requestObj = URLRequest(url: url(path: "api/Users/register"))
        requestObj.httpMethod = "POST"
        requestObj.setValue("application/json", forHTTPHeaderField: "Accept")
        requestObj.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requestObj.httpBody = data
        let (responseData, response) = try await session.data(for: requestObj)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: 0)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: httpResponse.statusCode)
        }
        return try decoder.decode(MessageResponse.self, from: responseData)
    }

    func googleLogin(idToken: String) async throws -> LoginResponse {
        let payload = ["idToken": idToken]
        let response: LoginResponse = try await request(
            url(path: "api/Users/google-login"),
            method: "POST",
            body: payload,
            requireAuth: false
        )
        self.jwtToken = response.token
        return response
    }

    func appleLogin(identityToken: String, firstName: String?, lastName: String?) async throws -> LoginResponse {
        var payload = ["identityToken": identityToken]
        if let firstName { payload["firstName"] = firstName }
        if let lastName { payload["lastName"] = lastName }
        let response: LoginResponse = try await request(
            url(path: "api/Users/apple-login"),
            method: "POST",
            body: payload,
            requireAuth: false
        )
        self.jwtToken = response.token
        return response
    }

    func updateProfile(_ profile: UpdateProfileRequest) async throws -> User {
        return try await request(
            url(path: "api/Users/profile"),
            method: "PUT",
            body: profile,
            requireAuth: true
        )
    }

    func uploadAvatar(imageData: Data, contentType: String = "image/jpeg") async throws -> User {
        var requestObj = URLRequest(url: url(path: "api/Users/profile/avatar"))
        requestObj.httpMethod = "POST"
        requestObj.setValue("application/json", forHTTPHeaderField: "Accept")
        requestObj.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let token = jwtToken {
            requestObj.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        requestObj.httpBody = imageData
        let (data, response) = try await session.data(for: requestObj)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: 0)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: httpResponse.statusCode)
        }
        return try decoder.decode(User.self, from: data)
    }

    /// Returns the user's custom avatar image bytes, or nil if none is set.
    func fetchAvatarData() async throws -> Data? {
        var requestObj = URLRequest(url: url(path: "api/Users/profile/avatar"))
        requestObj.httpMethod = "GET"
        if let token = jwtToken {
            requestObj.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: requestObj)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: 0)
        }
        if httpResponse.statusCode == 404 { return nil }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: httpResponse.statusCode)
        }
        return data
    }

    func deleteAvatar() async throws -> User {
        return try await request(
            url(path: "api/Users/profile/avatar"),
            method: "DELETE",
            requireAuth: true
        )
    }

    /// Permanently deletes the authenticated user's account and all associated data.
    /// Assumes the backend exposes `DELETE api/Users/profile`. Deliberately does NOT use
    /// the generic decoding `request` helper: a deleted account returns no user JSON, so we
    /// only validate the status code and tolerate an empty body (e.g. 204 No Content).
    func deleteAccount() async throws {
        var requestObj = URLRequest(url: url(path: "api/Users/profile"))
        requestObj.httpMethod = "DELETE"
        requestObj.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = jwtToken {
            requestObj.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (_, response) = try await session.data(for: requestObj)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: 0)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: httpResponse.statusCode)
        }
    }

    func completeWorkoutSession(_ session: CompleteWorkoutSessionRequest) async throws -> WorkoutSessionResponse {
        return try await request(
            url(path: "api/Workouts/sessions"),
            method: "POST",
            body: session,
            requireAuth: true
        )
    }

    func workoutSessions(page: Int = 1, pageSize: Int = 20) async throws -> WorkoutSessionListResponse {
        var components = try urlComponents(path: "api/Workouts/sessions")
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
        guard let url = components.url else {
            throw PickleballTrainingGenieError.invalidURL
        }
        return try await request(url, method: "GET", requireAuth: true)
    }

    func drillProgress() async throws -> [DrillProgressItem] {
        return try await request(
            url(path: "api/Drills/progress"),
            method: "GET",
            requireAuth: true
        )
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
        guard let url = components.url else {
            throw PickleballTrainingGenieError.invalidURL
        }
        return try await request(url, method: "GET", requireAuth: false)
    }

    func recommendations() async throws -> [Drill] {
        return try await request(
            url(path: "api/Drills/recommendations"),
            method: "GET",
            requireAuth: true
        )
    }

    func completeDrill(id: String) async throws -> MessageResponse {
        return try await request(
            url(path: "api/Drills/\(id)/complete"),
            method: "POST",
            body: [String: String](),
            requireAuth: true
        )
    }

    func generateWorkout(durationMinutes: Int? = nil) async throws -> WorkoutPlanResponse {
        let body = GenerateWorkoutRequest(durationMinutes: durationMinutes)
        return try await request(
            url(path: "api/workouts/generate"),
            method: "POST",
            body: body,
            requireAuth: true
        )
    }

    func urlComponents(path: String) throws -> URLComponents {
        guard let components = URLComponents(
            url: url(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw PickleballTrainingGenieError.invalidURL
        }
        return components
    }

    private func url(path: String) -> URL {
        baseURL.appending(path: path)
    }

    private func request<Response: Decodable>(
        _ url: URL,
        method: String,
        requireAuth: Bool
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if requireAuth, let token = jwtToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: 0)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: httpResponse.statusCode)
        }
        return try decoder.decode(Response.self, from: data)
    }

    private func request<Response: Decodable, Body: Encodable>(
        _ url: URL,
        method: String,
        body: Body,
        requireAuth: Bool
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requireAuth, let token = jwtToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: 0)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw PickleballTrainingGenieError.invalidResponse(statusCode: httpResponse.statusCode)
        }
        return try decoder.decode(Response.self, from: data)
    }
}

enum PickleballTrainingGenieError: Error, Equatable {
    case invalidURL
    case invalidResponse(statusCode: Int)
}
