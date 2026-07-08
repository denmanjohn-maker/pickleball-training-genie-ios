import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        if authViewModel.isAuthenticated {
            MainTabView()
                .environmentObject(authViewModel)
                .environmentObject(
                    DrillsViewModel(client: authViewModel.client)
                )
                .environmentObject(
                    TournamentsViewModel(
                        client: TournamentsAPIClient(baseURL: URL(string: TournamentsAPIConfig.baseURL)!)
                    )
                )
        } else {
            LoginView()
                .environmentObject(authViewModel)
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
        .tint(.neonVolt)
    }
}
