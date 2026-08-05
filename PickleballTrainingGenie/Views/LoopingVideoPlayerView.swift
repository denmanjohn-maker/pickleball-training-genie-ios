import SwiftUI
import UIKit
import AVFoundation
import CoreImage

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

/// Plays a bundled alpha-channel video on a silent, indefinite loop while
/// shaving `trimRadius` source pixels off the alpha silhouette of every frame
/// and feathering the new edge. Removes light fringe baked into the outermost
/// pixels of the artwork, which `LoopingVideoPlayerView` would show as-is.
struct EdgeTrimmedLoopingVideoView: UIViewRepresentable {
    let resourceName: String
    let resourceExtension: String
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    var trimRadius: CGFloat = 3

    func makeUIView(context: Context) -> TrimmedPlayerView {
        let view = TrimmedPlayerView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isOpaque = false
        view.trimRadius = trimRadius
        view.setGravity(videoGravity)

        if let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) {
            view.configure(with: url)
        }

        return view
    }

    func updateUIView(_ uiView: TrimmedPlayerView, context: Context) {
        uiView.trimRadius = trimRadius
        uiView.setGravity(videoGravity)
    }

    static func dismantleUIView(_ uiView: TrimmedPlayerView, coordinator: ()) {
        uiView.teardown()
    }

    final class TrimmedPlayerView: UIView {
        var trimRadius: CGFloat = 3

        private var player: AVPlayer?
        private var videoOutput: AVPlayerItemVideoOutput?
        private var displayLink: CADisplayLink?
        private var loopObserver: NSObjectProtocol?
        private let ciContext = CIContext()

        func configure(with url: URL) {
            let item = AVPlayerItem(url: url)
            // BGRA output preserves the video's alpha channel, unlike the
            // default opaque YUV formats.
            let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ])
            item.add(output)

            let player = AVPlayer(playerItem: item)
            player.isMuted = true
            player.actionAtItemEnd = .none
            loopObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak player] _ in
                player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
                player?.play()
            }

            layer.masksToBounds = true
            self.player = player
            self.videoOutput = output
            player.play()
        }

        func setGravity(_ gravity: AVLayerVideoGravity) {
            switch gravity {
            case .resizeAspectFill:
                layer.contentsGravity = .resizeAspectFill
            case .resize:
                layer.contentsGravity = .resize
            default:
                layer.contentsGravity = .resizeAspect
            }
        }

        func teardown() {
            player?.pause()
            displayLink?.invalidate()
            displayLink = nil
            if let loopObserver {
                NotificationCenter.default.removeObserver(loopObserver)
                self.loopObserver = nil
            }
            player = nil
            videoOutput = nil
        }

        // The display link retains its target, so it only runs while the view
        // is in a window and is invalidated on removal to break the cycle.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            displayLink?.invalidate()
            displayLink = nil
            guard window != nil, videoOutput != nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(renderFrame))
            // The source video is 30fps; don't tick at ProMotion's 120Hz.
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 60, preferred: 30)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        deinit {
            if let loopObserver {
                NotificationCenter.default.removeObserver(loopObserver)
            }
        }

        @objc private func renderFrame(_ link: CADisplayLink) {
            guard let videoOutput else { return }
            let itemTime = videoOutput.itemTime(forHostTime: link.targetTimestamp)
            guard videoOutput.hasNewPixelBuffer(forItemTime: itemTime),
                  let buffer = videoOutput.copyPixelBuffer(
                      forItemTime: itemTime,
                      itemTimeForDisplay: nil
                  )
            else { return }

            let source = CIImage(cvPixelBuffer: buffer)
            let trimmed = Self.trimEdges(of: source, radius: trimRadius)
            if let cgImage = ciContext.createCGImage(trimmed, from: source.extent) {
                layer.contents = cgImage
            }
        }

        /// Shrinks the frame's alpha matte by `radius` pixels and feathers the
        /// cut, so the outermost edge pixels are dropped.
        private static func trimEdges(of source: CIImage, radius: CGFloat) -> CIImage {
            guard radius > 0 else { return source }
            let alphaOnly = CIVector(x: 0, y: 0, z: 0, w: 1)
            let matte = source.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": alphaOnly,
                "inputGVector": alphaOnly,
                "inputBVector": alphaOnly,
                "inputAVector": alphaOnly
            ])
            let eroded = matte
                .applyingFilter("CIMorphologyMinimum", parameters: [
                    kCIInputRadiusKey: radius
                ])
                .applyingFilter("CIGaussianBlur", parameters: [
                    kCIInputRadiusKey: 0.7
                ])
                .cropped(to: source.extent)
            let clearBackground = CIImage(color: .clear).cropped(to: source.extent)
            return CIFilter(
                name: "CIBlendWithAlphaMask",
                parameters: [
                    kCIInputImageKey: source,
                    kCIInputBackgroundImageKey: clearBackground,
                    kCIInputMaskImageKey: eroded
                ]
            )?.outputImage ?? source
        }
    }
}
