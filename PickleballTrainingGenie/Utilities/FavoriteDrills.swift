import Foundation
import SwiftUI

/// Locally stored favorite drills — the player's own shortlist. Persisted in
/// UserDefaults; observable so hearts update everywhere at once.
@MainActor
final class FavoriteDrills: ObservableObject {
    static let shared = FavoriteDrills()

    @Published private(set) var ids: Set<String>

    private static let key = "drills.favorites"

    private init() {
        let stored = UserDefaults.standard.array(forKey: Self.key) as? [String]
        ids = Set(stored ?? [])
    }

    func contains(_ drillId: String) -> Bool {
        ids.contains(drillId)
    }

    func toggle(_ drillId: String) {
        if ids.contains(drillId) {
            ids.remove(drillId)
        } else {
            ids.insert(drillId)
        }
        UserDefaults.standard.set(Array(ids).sorted(), forKey: Self.key)
    }

    /// Forgets every favorite. Clearing the stored key alone isn't enough — this
    /// is a long-lived singleton, so the in-memory set has to go too or hearts
    /// stay filled for the rest of the process.
    func clearAll() {
        ids = []
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}
