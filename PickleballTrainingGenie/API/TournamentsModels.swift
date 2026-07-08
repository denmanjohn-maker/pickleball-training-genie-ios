import Foundation

struct Tournament: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let name: String
    let startDate: String
    let endDate: String?
    let venueName: String?
    let city: String
    let state: String
    let entryFee: Decimal?
    let currency: String?
    let registrationUrl: String?
    let source: String
    let sourceUrl: String
    let isCanceled: Bool
}

struct TournamentDetail: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let name: String
    let startDate: String
    let endDate: String?
    let venueName: String?
    let city: String
    let state: String
    let entryFee: Decimal?
    let currency: String?
    let registrationUrl: String?
    let source: String
    let sourceUrl: String
    let isCanceled: Bool
    let relatedSourceListings: [Tournament]
}

struct City: Codable, Equatable, Identifiable, Sendable {
    let id: Int
    let name: String
    let state: String
    let zip: String
    let events1Month: Int
    let events3Month: Int
}

struct TournamentListResponse: Codable, Sendable {
    let items: [Tournament]
    let page: Int
    let pageSize: Int
    let totalCount: Int
}
