import SwiftUI
import UIKit
import AVFoundation

/// Plays a bundled video on a silent, indefinite loop with no playback controls.
struct LoopingVideoPlayerView: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isOpaque = false
        view.playerLayer.backgroundColor = UIColor.clear.cgColor
        view.playerLayer.isOpaque = false

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) else {
            return view
        }

        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.isMuted = true

        view.playerLayer.player = queuePlayer
        view.playerLayer.videoGravity = videoGravity

        context.coordinator.player = queuePlayer
        context.coordinator.looper = looper

        queuePlayer.play()

        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.videoGravity = videoGravity
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        uiView.playerLayer.player = nil
        coordinator.player = nil
        coordinator.looper = nil
    }

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
