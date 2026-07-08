import Foundation
import SwiftUI

enum TournamentWindow: String, CaseIterable, Identifiable {
    case oneMonth = "1m"
    case threeMonth = "3m"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneMonth: return "1 Month"
        case .threeMonth: return "3 Months"
        }
    }
}

@MainActor
class TournamentsViewModel: ObservableObject {
    @Published var cities: [City] = []
    @Published var selectedCity: City?
    @Published var window: TournamentWindow = .oneMonth
    @Published var tournaments: [Tournament] = []
    @Published var totalCount: Int = 0
    @Published var page: Int = 1
    let pageSize = 25

    @Published var isLoadingCities = false
    @Published var isLoadingTournaments = false
    @Published var isLoadingMore = false
    @Published var citiesError: String?
    @Published var tournamentsError: String?
    @Published var loadMoreError: String?

    @Published var selectedTournamentDetail: TournamentDetail?
    @Published var isLoadingDetail = false
    @Published var detailError: String?

    private let client: TournamentsAPIClient
    private let defaults: UserDefaults
    private static let lastCityIdKey = "tournaments.lastCityId"

    var hasMorePages: Bool { tournaments.count < totalCount }

    init(client: TournamentsAPIClient, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
    }

    func loadCities() async {
        isLoadingCities = true
        citiesError = nil
        do {
            cities = try await client.cities()
            if selectedCity == nil {
                let savedId = defaults.integer(forKey: Self.lastCityIdKey)
                selectedCity = cities.first { $0.id == savedId } ?? cities.first
            }
        } catch let error as TournamentsAPIError {
            citiesError = message(for: error)
        } catch let error as URLError {
            citiesError = networkErrorMessage(for: error)
        } catch {
            citiesError = "Could not load cities: \(error.localizedDescription)"
        }
        isLoadingCities = false
    }

    func selectCity(_ city: City) async {
        selectedCity = city
        defaults.set(city.id, forKey: Self.lastCityIdKey)
        await loadTournaments(resetPage: true)
    }

    func setWindow(_ window: TournamentWindow) async {
        self.window = window
        await loadTournaments(resetPage: true)
    }

    func loadTournaments(resetPage: Bool) async {
        guard let selectedCity else { return }
        if resetPage {
            page = 1
            tournaments = []
            loadMoreError = nil
        }
        isLoadingTournaments = true
        tournamentsError = nil
        do {
            let response = try await client.tournaments(
                city: selectedCity.name,
                window: window.rawValue,
                page: page,
                pageSize: pageSize
            )
            tournaments = response.items
            totalCount = response.totalCount
        } catch let error as TournamentsAPIError {
            tournamentsError = message(for: error)
        } catch let error as URLError {
            tournamentsError = networkErrorMessage(for: error)
        } catch {
            tournamentsError = "Could not load tournaments: \(error.localizedDescription)"
        }
        isLoadingTournaments = false
    }

    func loadMoreTournaments() async {
        guard let selectedCity, hasMorePages, !isLoadingMore else { return }
        isLoadingMore = true
        loadMoreError = nil
        let nextPage = page + 1
        do {
            let response = try await client.tournaments(
                city: selectedCity.name,
                window: window.rawValue,
                page: nextPage,
                pageSize: pageSize
            )
            tournaments.append(contentsOf: response.items)
            totalCount = response.totalCount
            page = nextPage
        } catch let error as TournamentsAPIError {
            loadMoreError = message(for: error)
        } catch let error as URLError {
            loadMoreError = networkErrorMessage(for: error)
        } catch {
            loadMoreError = "Could not load more tournaments: \(error.localizedDescription)"
        }
        isLoadingMore = false
    }

    func loadDetail(id: Int) async {
        isLoadingDetail = true
        detailError = nil
        do {
            selectedTournamentDetail = try await client.tournament(id: id)
        } catch let error as TournamentsAPIError {
            detailError = message(for: error)
        } catch let error as URLError {
            detailError = networkErrorMessage(for: error)
        } catch {
            detailError = "Could not load tournament: \(error.localizedDescription)"
        }
        isLoadingDetail = false
    }

    func clearDetail() {
        selectedTournamentDetail = nil
        detailError = nil
    }

    private func message(for error: TournamentsAPIError) -> String {
        switch error {
        case .notFound:
            return "This tournament is no longer available."
        case .invalidResponse(let code) where code == 0:
            return connectionErrorMessage()
        case .invalidResponse(let code):
            return "Request failed (error \(code))."
        case .invalidURL:
            return "Invalid server configuration."
        }
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
        return "Cannot reach \(url). On a physical device, set TOURNAMENTS_API_BASE_URL to your Mac's local IP instead of localhost when testing against a local backend."
    }
}
