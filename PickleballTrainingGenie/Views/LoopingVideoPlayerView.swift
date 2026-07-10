import SwiftUI
import AVFoundation

/// Plays a bundled video on a silent, indefinite loop with no playback controls.
struct LoopingVideoPlayerView: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) else {
            return view
        }

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.isMuted = true

        view.playerLayer.player = queuePlayer
        view.playerLayer.videoGravity = .resizeAspect

        context.coordinator.player = queuePlayer
        context.coordinator.looper = looper

        queuePlayer.play()

        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    final class PlayerContainerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
