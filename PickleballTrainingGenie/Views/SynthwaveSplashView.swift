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

    /// Center-cropped genie video framed in neon, floating on a cosmic aura
    /// so the footage's dark backdrop melts into the synthwave gradient.
    private var genieHero: some View {
        LoopingVideoPlayerView(
            resourceName: "SplashVideo",
            resourceExtension: "mp4",
            videoGravity: .resizeAspectFill
        )
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(
            // Soft inner vignette so the crop line fades into the frame
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.deepSpace.opacity(0.55), lineWidth: 12)
                .blur(radius: 10)
                .clipShape(RoundedRectangle(cornerRadius: 28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(
                    LinearGradient(
                        colors: [.neonMagenta, .neonCyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
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
