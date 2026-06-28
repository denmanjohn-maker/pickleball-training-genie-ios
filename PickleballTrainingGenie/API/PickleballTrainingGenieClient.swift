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
    let singlesDUPR: Decimal?
    let doublesDUPR: Decimal?
    let isDuprLinked: Bool
    let preferredSessionDurationMinutes: Int?
    let targetDUPR: Decimal
}

struct LoginResponse: Codable, Equatable, Sendable {
    let token: String
}

struct MessageResponse: Codable, Equatable, Sendable {
    let message: String
}

struct GenerateWorkoutRequest: Codable, Sendable {
    let durationMinutes: Int?
}

struct WorkoutDrillItem: Codable, Identifiable, Sendable {
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
