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
                    AuthenticatedMainView(client: authViewModel.client, userId: user.id)
                        .id(user.id)
                        .environmentObject(authViewModel)
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

private struct AuthenticatedMainView: View {
    @StateObject private var drills: DrillsViewModel
    @StateObject private var activity: TrainingStreakStore
    @StateObject private var tournaments = TournamentsViewModel(
        client: TournamentsAPIClient(baseURL: URL(string: TournamentsAPIConfig.baseURL)!)
    )

    init(client: PickleballTrainingGenieClient, userId: String) {
        let activity = TrainingStreakStore(client: client, userId: userId)
        _activity = StateObject(wrappedValue: activity)
        _drills = StateObject(wrappedValue: DrillsViewModel(
            client: client, userId: userId, trainingStreakStore: activity
        ))
    }

    var body: some View {
        MainTabView()
            .environmentObject(drills)
            .environmentObject(activity)
            .environmentObject(tournaments)
    }
}

private struct ProfileLoadFailedView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            SynthwaveGradient()
            VStack(spacing: 16) {
                Image(systemName: "wifi.slash")
                    .font(.largeTitle)
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
enum AppSection: String, CaseIterable, Identifiable {
    case today, workout, drills, progress, profile

    static func restored(from rawValue: String) -> AppSection {
        AppSection(rawValue: rawValue) ?? .today
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drills: return "Drills"
        case .today: return "Today"
        case .workout: return "Train"
        case .progress: return "Progress"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .drills: return "figure.racquetball"
        case .today: return "sun.max.fill"
        case .workout: return "bolt.fill"
        case .progress: return "chart.bar.fill"
        case .profile: return "person.fill"
        }
    }

    /// The recommendation empty state jumps to the layout's Drills selection.
    @ViewBuilder func destination(
        onBrowseAllDrills: @escaping () -> Void,
        onOpenWorkout: @escaping () -> Void = {}
    ) -> some View {
        switch self {
        case .drills: DrillsListView()
        case .today: TodayView(onBrowseAllDrills: onBrowseAllDrills, onOpenWorkout: onOpenWorkout)
        case .workout: WorkoutView()
        case .progress: TrainingProgressView()
        case .profile: ProfileView()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var drillsViewModel: DrillsViewModel
    @EnvironmentObject var trainingStreakStore: TrainingStreakStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // SceneStorage (not State) so the chosen section survives the view-tree
    // re-init that happens when the size class flips (e.g. iPad Split View).
    @SceneStorage("mainTab.selection") private var selectionRaw = AppSection.today.rawValue

    private var selection: AppSection {
        AppSection.restored(from: selectionRaw)
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
            selectionRaw = selection.rawValue
            seedTournamentCityFromProfile()
        }
        .task {
            // Restore server-side drill completions so history survives restarts.
            await drillsViewModel.loadDrillProgress()
        }
        .task { await trainingStreakStore.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await trainingStreakStore.load() }
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            guard scenePhase == .active else { return }
            Task { await trainingStreakStore.refreshForCalendarChange() }
        }
    }

    // MARK: iPhone (compact) — bottom tab bar

    private var tabLayout: some View {
        TabView(selection: Binding(
            get: { selection },
            set: { selectionRaw = $0.rawValue }
        )) {
            ForEach(AppSection.allCases) { section in
                destinationView(for: section)
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
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(section.title)
                        .accessibilityIdentifier("mainSection.\(section.rawValue)")
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
            .navigationSplitViewColumnWidth(
                min: dynamicTypeSize.isAccessibilitySize ? 320 : 220,
                ideal: dynamicTypeSize.isAccessibilitySize ? 360 : 260,
                max: dynamicTypeSize.isAccessibilitySize ? 440 : 300
            )
        } detail: {
            // Each section owns its own NavigationStack; switching the
            // @ViewBuilder branch recreates it, mirroring tab-switch semantics.
            destinationView(for: selection)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func destinationView(for section: AppSection) -> some View {
        section.destination(
            onBrowseAllDrills: { selectionRaw = AppSection.drills.rawValue },
            onOpenWorkout: {
                drillsViewModel.reviewSavedWorkout = drillsViewModel.workout != nil
                selectionRaw = AppSection.workout.rawValue
            }
        )
    }

    /// On a fresh install Tournaments has no saved city; default it to
    /// the home city chosen during onboarding.
    private func seedTournamentCityFromProfile() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "tournaments.lastCityId") == nil,
           let homeCityId = authViewModel.currentUser?.homeCityId {
            defaults.set(homeCityId, forKey: "tournaments.lastCityId")
        }
    }
}
