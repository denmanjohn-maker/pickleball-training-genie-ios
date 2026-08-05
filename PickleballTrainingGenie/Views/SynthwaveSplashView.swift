import SwiftUI

struct SynthwaveSplashView: View {
    let onComplete: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            SynthwaveGradient()
            StarFieldView()
                .ignoresSafeArea()

            VStack(spacing: 24) {
                GenieWordmark()

                Spacer(minLength: 0)

                genieHero

                Spacer(minLength: 0)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .scaleEffect(appeared ? 1.0 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onComplete)
        .onAppear {
            withAnimation(ECAnimation.snappyVolley) { appeared = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(2.0))
            onComplete()
        }
    }

    /// Genie video with a real alpha channel. The source frame is wide
    /// (854×480) with the genie centered in roughly the middle 432×448 px,
    /// so an aspect-fill crop at that aspect trims the empty side margins
    /// and lets the genie render large. The edge-trimmed player shaves the
    /// light rim baked into the artwork's outermost pixels.
    private var genieHero: some View {
        EdgeTrimmedLoopingVideoView(
            resourceName: "SplashVideo",
            resourceExtension: "mov",
            videoGravity: .resizeAspectFill,
            trimRadius: 3
        )
        .aspectRatio(432.0 / 448.0, contentMode: .fit)
        .frame(maxWidth: 340)
        .clipped()
    }
}

#Preview {
    SynthwaveSplashView {}
}
