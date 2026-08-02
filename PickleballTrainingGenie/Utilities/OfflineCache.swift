import Foundation

/// Small JSON disk cache so core content survives a dead signal — outdoor
/// courts are exactly where connectivity fails and exactly where the app is
/// needed. Values live in Application Support (not purged like Caches) and
/// carry their save date so the UI can say how fresh they are.
enum OfflineCache {
    struct Entry<Value: Codable>: Codable {
        let savedAt: Date
        let value: Value
    }

    private static var directory: URL? {
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        let dir = base.appendingPathComponent("OfflineCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(for key: String) -> URL? {
        directory?.appendingPathComponent("\(key).json")
    }

    static func save<Value: Codable>(_ value: Value, key: String) {
        guard let url = fileURL(for: key),
              let data = try? JSONEncoder().encode(Entry(savedAt: Date(), value: value))
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load<Value: Codable>(_ type: Value.Type, key: String) -> Entry<Value>? {
        guard let url = fileURL(for: key),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(Entry<Value>.self, from: data)
    }

    static func remove(key: String) {
        guard let url = fileURL(for: key) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
