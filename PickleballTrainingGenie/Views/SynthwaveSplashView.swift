import SwiftUI

struct SynthwaveSplashView: View {
    let onComplete: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            SynthwaveGradient()
            StarFieldView()
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Image("SplashArtwork")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.neonMagenta, .neonCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .neonGlow(.neonMagenta, radius: 18)

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

                LoopingVideoPlayerView(resourceName: "SplashVideo", resourceExtension: "mov")
                    .frame(maxWidth: 320)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.neonMagenta, .neonCyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .neonGlow(.neonCyan, radius: 14)
            }
            .padding(.horizontal, 24)
            .scaleEffect(appeared ? 1.0 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onComplete)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(2.0))
            onComplete()
        }
    }
}

#Preview {
    SynthwaveSplashView {}
}
