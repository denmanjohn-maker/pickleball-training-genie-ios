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

/// The app's five top-level destinations, shared by the iPhone tab bar and the
/// iPad sidebar so both layouts stay in sync.
private enum AppSection: String, CaseIterable, Identifiable {
    case drills, forYou, workout, tournaments, profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drills: return "Drills"
        case .forYou: return "For You"
        case .workout: return "Workout"
        case .tournaments: return "Tournaments"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .drills: return "figure.racquetball"
        case .forYou: return "star.fill"
        case .workout: return "bolt.fill"
        case .tournaments: return "trophy.fill"
        case .profile: return "person.fill"
        }
    }

    @ViewBuilder var destination: some View {
        switch self {
        case .drills: DrillsListView()
        case .forYou: RecommendationsView()
        case .workout: WorkoutView()
        case .tournaments: TournamentsListView()
        case .profile: ProfileView()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var drillsViewModel: DrillsViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // SceneStorage (not State) so the chosen section survives the view-tree
    // re-init that happens when the size class flips (e.g. iPad Split View).
    @SceneStorage("mainTab.selection") private var selectionRaw = AppSection.drills.rawValue

    private var selection: AppSection {
        AppSection(rawValue: selectionRaw) ?? .drills
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                sidebarLayout
            } else {
                tabLayout
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

    // MARK: iPhone (compact) — bottom tab bar

    private var tabLayout: some View {
        TabView(selection: Binding(
            get: { selection },
            set: { selectionRaw = $0.rawValue }
        )) {
            ForEach(AppSection.allCases) { section in
                section.destination
                    .tabItem { Label(section.title, systemImage: section.icon) }
                    .tag(section)
            }
        }
    }

    // MARK: iPad (regular) — sidebar

    private var sidebarLayout: some View {
        NavigationSplitView {
            List(selection: Binding<AppSection?>(
                get: { selection },
                set: { selectionRaw = ($0 ?? selection).rawValue }
            )) {
                ForEach(AppSection.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .foregroundStyle(section == selection ? Color.neonMagenta : Color.white)
                        .tag(section)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(section == selection ? Color.neonMagenta.opacity(0.22) : Color.clear)
                        )
                }
            }
            .scrollContentBackground(.hidden)
            .background(SynthwaveGradient())
            .navigationTitle("Genie")
            .genieBrandIconToolbar()
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } detail: {
            // Each section owns its own NavigationStack; switching the
            // @ViewBuilder branch recreates it, mirroring tab-switch semantics.
            selection.destination
        }
        .navigationSplitViewStyle(.balanced)
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
