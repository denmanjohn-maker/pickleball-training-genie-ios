import Foundation

enum TournamentsAPIConfig {
    static let baseURL = ProcessInfo.processInfo.environment["TOURNAMENTS_API_BASE_URL"]
        ?? "https://pickleballtournamentapi.com/"
}

enum TournamentsAPIError: Error, Equatable {
    case invalidURL
    case invalidResponse(statusCode: Int)
    case notFound
}

class TournamentsAPIClient {
    let baseURL: URL
    let session: URLSession
    private let decoder = JSONDecoder()

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func cities() async throws -> [City] {
        try await request(url(path: "api/cities"))
    }

    func tournaments(
        city: String? = nil,
        window: String? = nil,
        page: Int = 1,
        pageSize: Int = 25
    ) async throws -> TournamentListResponse {
        var components = try urlComponents(path: "api/tournaments")
        var queryItems: [URLQueryItem] = []
        if let city {
            queryItems.append(URLQueryItem(name: "city", value: city))
        }
        if let window {
            queryItems.append(URLQueryItem(name: "window", value: window))
        }
        queryItems.append(URLQueryItem(name: "page", value: String(page)))
        queryItems.append(URLQueryItem(name: "pageSize", value: String(pageSize)))
        components.queryItems = queryItems
        guard let url = components.url else {
            throw TournamentsAPIError.invalidURL
        }
        return try await request(url)
    }

    func tournament(id: Int) async throws -> TournamentDetail {
        try await request(url(path: "api/tournaments/\(id)"))
    }

    private func urlComponents(path: String) throws -> URLComponents {
        guard let components = URLComponents(
            url: url(path: path),
            resolvingAgainstBaseURL: false
        ) else {
            throw TournamentsAPIError.invalidURL
        }
        return components
    }

    private func url(path: String) -> URL {
        baseURL.appending(path: path)
    }

    private func request<Response: Decodable>(_ url: URL) async throws -> Response {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TournamentsAPIError.invalidResponse(statusCode: 0)
        }
        if httpResponse.statusCode == 404 {
            throw TournamentsAPIError.notFound
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw TournamentsAPIError.invalidResponse(statusCode: httpResponse.statusCode)
        }
        return try decoder.decode(Response.self, from: data)
    }
}
