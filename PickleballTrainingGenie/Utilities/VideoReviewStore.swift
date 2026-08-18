import Foundation
import SwiftUI

/// One recorded practice clip. The video file lives in Documents/VideoReview;
/// metadata is a sidecar JSON. Everything stays on-device — clips are never
/// uploaded anywhere.
struct VideoClip: Codable, Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let category: String
    let createdAt: Date
}

@MainActor
final class VideoReviewStore: ObservableObject {
    static let shared = VideoReviewStore()

    @Published private(set) var clips: [VideoClip] = []

    private let directory: URL?
    private var metadataURL: URL? {
        directory?.appendingPathComponent("clips.json")
    }

    private init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        directory = documents?.appendingPathComponent("VideoReview", isDirectory: true)
        if var directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // "Clips never leave your device" must include iCloud backup —
            // exclude the whole folder so recordings are never uploaded.
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? directory.setResourceValues(values)
        }
        load()
    }

    func url(for clip: VideoClip) -> URL? {
        directory?.appendingPathComponent(clip.fileName)
    }

    /// Moves a freshly recorded video from its temporary location into the
    /// store. Returns the new clip, or nil if the move failed.
    @discardableResult
    func addClip(from temporaryURL: URL, category: String) -> VideoClip? {
        guard let directory else { return nil }
        let clip = VideoClip(
            id: UUID(),
            fileName: "\(UUID().uuidString).\(temporaryURL.pathExtension.isEmpty ? "mov" : temporaryURL.pathExtension)",
            category: category,
            createdAt: Date()
        )
        let destination = directory.appendingPathComponent(clip.fileName)
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
        } catch {
            return nil
        }
        clips.insert(clip, at: 0)
        persist()
        return clip
    }

    func delete(_ clip: VideoClip) {
        if let url = url(for: clip) {
            try? FileManager.default.removeItem(at: url)
        }
        clips.removeAll { $0.id == clip.id }
        persist()
    }

    /// Removes every clip and its file. Recordings are the one thing here that
    /// exists *only* on this device — deleting an account server-side can't
    /// reach them, so account deletion has to call this explicitly.
    func deleteAll() {
        for clip in clips {
            if let url = url(for: clip) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        clips = []
        persist()
    }

    private func load() {
        guard let metadataURL,
              let data = try? Data(contentsOf: metadataURL),
              let stored = try? JSONDecoder().decode([VideoClip].self, from: data)
        else { return }
        clips = stored.sorted { $0.createdAt > $1.createdAt }
    }

    private func persist() {
        guard let metadataURL,
              let data = try? JSONEncoder().encode(clips)
        else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }
}

/// What a coach's eye would check per skill — shown alongside playback so the
/// player knows what to look for in their own form.
enum FormCheckpoints {
    static let byCategory: [String: [String]] = [
        "Serving": [
            "Contact below the waist, paddle moving upward",
            "Weight transfers from back foot to front",
            "Follow-through finishes toward your target",
            "Ball lands deep in the service box"
        ],
        "Dinking": [
            "Paddle out in front, wrist firm",
            "Motion comes from the shoulder, not the wrist",
            "Knees bent — lift with your legs",
            "Ball peaks on your side of the net"
        ],
        "Drops": [
            "Low-to-high stroke with a soft grip",
            "Arc peaks before the net, not after",
            "Ball lands in the kitchen, unattackable",
            "You're moving forward as you hit"
        ],
        "Volleys": [
            "Paddle up and in front at all times",
            "Short, compact punch — no backswing",
            "Return to ready position after every hit",
            "Contact out in front of your body"
        ],
        "Returns": [
            "Split-step as the server makes contact",
            "Return goes deep, past mid-court",
            "You follow the return toward the kitchen line",
            "Balanced finish — not falling backward"
        ],
        "Attacking": [
            "Only attacking balls above net height",
            "Contact out in front, weight moving forward",
            "Aim at feet or open court, not just hard",
            "Ready for the counter immediately after"
        ],
        "Resets": [
            "Soft grip absorbs the pace",
            "Paddle face slightly open, blocking not swinging",
            "Ball dies in the kitchen",
            "Body stays low and balanced under pressure"
        ],
        "Movement": [
            "Split-step every time the opponent hits",
            "Small adjustment steps near the ball",
            "Moving through the transition zone, not camping",
            "Recovering to position after every shot"
        ]
    ]

    static func checkpoints(for category: String) -> [String] {
        byCategory[category] ?? [
            "Balanced, athletic stance throughout",
            "Paddle up and ready between shots",
            "Contact out in front of your body",
            "Controlled follow-through toward your target"
        ]
    }
}
