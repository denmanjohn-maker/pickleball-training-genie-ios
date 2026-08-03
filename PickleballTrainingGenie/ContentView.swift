import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("tutorial.hasSeenAppIntro") private var hasSeenAppIntro = false

    var body: some View {
        if authViewModel.isAuthenticated {
            if let user = authViewModel.currentUser {
                if user.needsOnboarding {
                    OnboardingFlowView()
                        .environmentObject(authViewModel)
                } else if !hasSeenAppIntro {
                    AppTutorialView(onComplete: { hasSeenAppIntro = true })
                } else {
                    MainTabView()
                        .environmentObject(authViewModel)
                        .environmentObject(
                            DrillsViewModel(client: authViewModel.client, userId: user.id)
                        )
                        .environmentObject(
                            TournamentsViewModel(
                                client: TournamentsAPIClient(baseURL: URL(string: TournamentsAPIConfig.baseURL)!)
                            )
                        )
                }
            } else if authViewModel.profileLoadFailed {
                ProfileLoadFailedView()
                    .environmentObject(authViewModel)
            } else {
                ZStack {
                    SynthwaveGradient()
                    ProgressView()
                        .tint(.neonMagenta)
                        .scaleEffect(1.4)
                }
            }
        } else {
            LoginView()
                .environmentObject(authViewModel)
        }
    }
}

private struct ProfileLoadFailedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            SynthwaveGradient()
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.neonMagenta)
                Text("Couldn't load your profile")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Check your connection and try again.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                Button {
                    Task { await authViewModel.fetchProfile() }
                } label: {
                    Text("Try Again")
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 180)

                Button("Sign Out") {
                    authViewModel.logout()
                }
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            }
            .padding()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var drillsViewModel: DrillsViewModel

    var body: some View {
        TabView {
            DrillsListView()
                .tabItem {
                    Label("Drills", systemImage: "figure.racquetball")
                }

            RecommendationsView()
                .tabItem {
                    Label("For You", systemImage: "star.fill")
                }

            WorkoutView()
                .tabItem {
                    Label("Workout", systemImage: "bolt.fill")
                }

            TournamentsListView()
                .tabItem {
                    Label("Tournaments", systemImage: "trophy.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(.neonMagenta)
        .onAppear {
            seedTournamentCityFromProfile()
        }
        .task {
            // Restore server-side drill completions so history survives restarts.
            await drillsViewModel.loadDrillProgress()
        }
    }

    /// On a fresh install the Tournaments tab has no saved city; default it to
    /// the home city chosen during onboarding.
    private func seedTournamentCityFromProfile() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "tournaments.lastCityId") == nil,
           let homeCityId = authViewModel.currentUser?.homeCityId {
            defaults.set(homeCityId, forKey: "tournaments.lastCityId")
        }
    }
}
