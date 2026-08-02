import SwiftUI
import AVKit
import UIKit

/// Video self-review: record a stroke, watch it back in slow motion against a
/// per-skill form checklist, and compare clips over time. The closest thing to
/// a coach's eye without one — and every clip stays on this device.
struct VideoReviewView: View {
    @ObservedObject private var store = VideoReviewStore.shared
    @State private var showRecordSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Be your own coach's eye")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Film a stroke, slow it down, and check it against the form points a coach would watch. Clips never leave your device.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 8)

                Button {
                    showRecordSheet = true
                } label: {
                    HStack {
                        Image(systemName: "video.fill.badge.plus")
                        Text("Record a Clip")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                if store.clips.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No clips yet")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Prop your phone against your bag, hit record, and film 30 seconds of serves or dinks.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                } else {
                    ForEach(store.clips) { clip in
                        NavigationLink {
                            ClipPlayerView(clip: clip)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.title2)
                                    .foregroundColor(.neonCyan)
                                VStack(alignment: .leading, spacing: 3) {
                                    CategoryBadge(category: clip.category)
                                    Text(clip.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .pickleballCard()
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.deepSpace)
        .navigationTitle("Video Review")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showRecordSheet) {
            RecordClipSheet()
        }
    }
}

// MARK: - Recording

private struct RecordClipSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category = "Serving"
    @State private var showCamera = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("What are you working on?")
                    .font(.headline)

                Picker("Skill", selection: $category) {
                    ForEach(Array(FormCheckpoints.byCategory.keys).sorted(), id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
                .pickerStyle(.wheel)

                VStack(alignment: .leading, spacing: 6) {
                    Text("You'll check for:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    ForEach(FormCheckpoints.checkpoints(for: category), id: \.self) { point in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "eye")
                                .font(.caption2)
                                .foregroundColor(.neonCyan)
                            Text(point)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .pickleballCard()
                .padding(.horizontal)

                if cameraAvailable {
                    Button {
                        showCamera = true
                    } label: {
                        HStack {
                            Image(systemName: "video.fill")
                            Text("Open Camera")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal)
                } else {
                    Text("Camera isn't available on this device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.top)
            .background(Color.deepSpace)
            .navigationTitle("Record a Clip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.neonCyan)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraRecorder(category: category) {
                    dismiss()
                }
                .ignoresSafeArea()
            }
        }
    }
}

/// System camera in video mode. Recorded movies land in `VideoReviewStore`.
private struct CameraRecorder: UIViewControllerRepresentable {
    let category: String
    let onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(category: category, onFinished: onFinished)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.cameraCaptureMode = .video
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let category: String
        let onFinished: () -> Void

        init(category: String, onFinished: @escaping () -> Void) {
            self.category = category
            self.onFinished = onFinished
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let url = info[.mediaURL] as? URL {
                let category = category
                Task { @MainActor in
                    VideoReviewStore.shared.addClip(from: url, category: category)
                }
            }
            picker.dismiss(animated: true)
            onFinished()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onFinished()
        }
    }
}

// MARK: - Playback

private struct ClipPlayerView: View {
    let clip: VideoClip
    @ObservedObject private var store = VideoReviewStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var playbackRate: Float = 1.0
    @State private var showDeleteConfirmation = false

    private let rates: [Float] = [0.25, 0.5, 1.0]

    var body: some View {
        VStack(spacing: 16) {
            if let player {
                VideoPlayer(player: player)
                    .frame(maxHeight: 420)
                    .cornerRadius(16)
                    .padding(.horizontal)
            } else {
                ContentUnavailableView {
                    Label("Clip Missing", systemImage: "video.slash")
                } description: {
                    Text("This clip's video file couldn't be found.")
                }
            }

            // Slow motion — where form flaws become visible.
            HStack(spacing: 10) {
                ForEach(rates, id: \.self) { rate in
                    Button {
                        playbackRate = rate
                        // Setting rate on a playing player applies live.
                        if let player, player.timeControlStatus == .playing {
                            player.rate = rate
                        }
                    } label: {
                        Text(rate == 1.0 ? "1×" : String(format: "%g×", rate))
                            .font(.subheadline)
                            .fontWeight(playbackRate == rate ? .bold : .regular)
                            .foregroundColor(playbackRate == rate ? .black : .primary)
                            .frame(width: 60, height: 36)
                            .background(playbackRate == rate ? Color.neonCyan : Color.nebulaSurface)
                            .cornerRadius(10)
                    }
                    .accessibilityLabel("Playback speed \(rate == 1.0 ? "normal" : String(format: "%g times", rate))")
                }
                Button {
                    player?.seek(to: .zero)
                    player?.playImmediately(atRate: playbackRate)
                } label: {
                    Label("Replay", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .foregroundColor(.neonMagenta)
                        .frame(height: 36)
                        .padding(.horizontal, 10)
                        .background(Color.neonMagenta.opacity(0.12))
                        .cornerRadius(10)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Check your form", systemImage: "eye.fill")
                        .font(.headline)
                        .foregroundColor(.starlight)
                    ForEach(FormCheckpoints.checkpoints(for: clip.category), id: \.self) { point in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.neonCyan)
                            Text(point)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .pickleballCard()
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color.deepSpace)
        .navigationTitle(clip.category)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Delete clip")
            }
        }
        .confirmationDialog(
            "Delete this clip?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Clip", role: .destructive) {
                store.delete(clip)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            if player == nil, let url = store.url(for: clip),
               FileManager.default.fileExists(atPath: url.path) {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
}

#Preview {
    NavigationStack { VideoReviewView() }
}
