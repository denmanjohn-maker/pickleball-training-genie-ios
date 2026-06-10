import SwiftUI
import AVFoundation

struct SplashVideoView: View {
    let onComplete: () -> Void
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
            }
        }
        .onTapGesture { onComplete() }
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }

    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "intro_video", withExtension: "mp4") else {
            onComplete()
            return
        }
        let p = AVPlayer(url: url)
        player = p
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in onComplete() }
        p.play()
    }
}

private struct VideoPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> _PlayerUIView { _PlayerUIView(player: player) }
    func updateUIView(_ uiView: _PlayerUIView, context: Context) {}
}

final class _PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    init(player: AVPlayer) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) { fatalError() }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
