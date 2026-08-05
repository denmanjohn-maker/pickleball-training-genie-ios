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

    /// Still of the genie extracted from the splash video, pre-cropped to the
    /// character with the matte cleaned up (edge rim removed and feathered).
    private var genieHero: some View {
        Image(decorative: "SplashGenie")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 340)
    }
}

#Preview {
    SynthwaveSplashView {}
}
