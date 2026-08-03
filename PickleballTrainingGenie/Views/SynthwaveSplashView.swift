import SwiftUI

struct SynthwaveSplashView: View {
    let onComplete: () -> Void
    @State private var appeared = false
    @State private var auraBreathing = false

    var body: some View {
        ZStack {
            SynthwaveGradient()
            StarFieldView()
                .ignoresSafeArea()

            VStack(spacing: 32) {
                genieHero

                Text("PICKLEBALL GENIE")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .kerning(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neonMagenta, .neonCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .neonGlow(.neonMagenta, radius: 10)
            }
            .padding(.horizontal, 24)
            .scaleEffect(appeared ? 1.0 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onComplete)
        .onAppear {
            withAnimation(ECAnimation.snappyVolley) { appeared = true }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                auraBreathing = true
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(2.0))
            onComplete()
        }
    }

    /// Genie video with a real alpha channel, floating on a cosmic aura
    /// with no frame or crop needed since the background is transparent.
    private var genieHero: some View {
        LoopingVideoPlayerView(
            resourceName: "SplashVideo",
            resourceExtension: "mov",
            videoGravity: .resizeAspect
        )
        .aspectRatio(854.0 / 480.0, contentMode: .fit)
        .frame(maxWidth: 320)
        .background(
            RadialGradient(
                colors: [Color.cosmicPurple.opacity(0.55), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 230
            )
            .frame(width: 460, height: 460)
            .scaleEffect(auraBreathing ? 1.08 : 0.92)
            .opacity(auraBreathing ? 1.0 : 0.7)
            .allowsHitTesting(false)
        )
        .neonGlow(.neonMagenta, radius: 18)
    }
}

#Preview {
    SynthwaveSplashView {}
}
