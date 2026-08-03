import SwiftUI

/// One-time, swipeable introduction to Pickleball Genie's goal and tabs.
/// Shown right after `OnboardingFlowView` finishes and before the tab bar
/// first appears; also replayable on demand from `ProfileView`.
struct AppTutorialView: View {
    let onComplete: () -> Void

    @State private var pageIndex = 0

    private let pages: [TutorialPage] = [
        TutorialPage(
            icon: "sparkles",
            title: "Welcome to Pickleball Genie",
            description: "Your AI-powered pickleball coach. We build personalized drills and workouts around your DUPR rating so every session moves your game forward."
        ),
        TutorialPage(
            icon: "figure.racquetball",
            title: "Browse Drills",
            description: "Explore a full library of drills organized by skill and category, and track your progress as you complete them."
        ),
        TutorialPage(
            icon: "star.fill",
            title: "Get Picks Made For You",
            description: "The For You tab recommends drills matched to your rating and goals, so you always know what to practice next."
        ),
        TutorialPage(
            icon: "bolt.fill",
            title: "AI-Generated Workouts",
            description: "Tell the Genie how much time you have, and get a complete, ready-to-run training session."
        ),
        TutorialPage(
            icon: "trophy.fill",
            title: "Find Tournaments",
            description: "Discover upcoming tournaments near you and keep track of the ones you want to play."
        ),
        TutorialPage(
            icon: "person.fill",
            title: "Track Your Growth",
            description: "Manage your DUPR ratings, review your workout history, and set training reminders — all from your Profile."
        ),
    ]

    var body: some View {
        ZStack {
            SynthwaveGradient()
            StarFieldView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                TabView(selection: $pageIndex) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageCard(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                navigationButtons
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quick Tour")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.neonMagenta, .neonCyan], startPoint: .leading, endPoint: .trailing)
                    )
                Spacer()
                Button("Skip") { onComplete() }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 20)

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= pageIndex ? Color.neonMagenta : Color.white.opacity(0.2))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func pageCard(_ page: TutorialPage) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 56))
                .foregroundColor(.neonMagenta)
                .neonGlow(.neonMagenta, radius: 12)

            Text(page.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.neonMagenta, .neonCyan], startPoint: .leading, endPoint: .trailing)
                )
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .pickleballCard()
        .padding(.horizontal, 20)
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if pageIndex != 0 {
                Button {
                    withAnimation { pageIndex -= 1 }
                } label: {
                    Text("Back")
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 100)
            }

            if pageIndex == pages.count - 1 {
                Button {
                    onComplete()
                } label: {
                    Text("Get Started 🎾")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button {
                    withAnimation { pageIndex += 1 }
                } label: {
                    Text("Next")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
}

private struct TutorialPage {
    let icon: String
    let title: String
    let description: String
}

#Preview {
    AppTutorialView(onComplete: {})
}
