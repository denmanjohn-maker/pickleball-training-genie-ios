import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var drillsViewModel: DrillsViewModel
    @State private var selectedDrill: Drill?
    let onBrowseAllDrills: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Make time for your game")
                            .font(.title2.bold())
                        Text(drillsViewModel.workout == nil
                             ? "Choose your session length and build a plan when you're ready."
                             : "Your saved plan is ready to review. Start or complete it only when you choose.")
                            .foregroundStyle(.secondary)
                        NavigationLink {
                            WorkoutView(ownsNavigationStack: false, reviewSavedWorkout: true)
                        } label: {
                            Label(drillsViewModel.workoutActionTitle, systemImage: "bolt.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        if let date = drillsViewModel.cachedWorkoutDate {
                            Text("Saved on \(date.formatted(date: .abbreviated, time: .shortened)). This is a plan, not an in-progress session.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .pickleballCard()

                    VStack(alignment: .leading, spacing: 12) {
                        Label("Your Training", systemImage: "flame.fill")
                            .font(.headline)
                        TrainingActivitySummary()
                    }
                    .padding()
                    .pickleballCard()

                    recommendations

                    NavigationLink {
                        TournamentsListView()
                    } label: {
                        dashboardLink("Find Tournaments", detail: "Explore events near your city", icon: "trophy.fill")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        LearnView()
                    } label: {
                        dashboardLink("Learn the Basics", detail: "Rules, scoring, and terminology, available offline", icon: "book.fill")
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .readableWidth()
            }
            .background(Color.deepSpace)
            .navigationTitle("Today")
            .genieBrandIconToolbar()
            .sheet(item: $selectedDrill) { drill in
                DrillDetailView(drill: drill)
            }
            .task {
                if drillsViewModel.recommendations.isEmpty {
                    await drillsViewModel.loadRecommendations()
                }
            }
        }
    }

    private var recommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recommended for You", systemImage: "star.fill")
                .font(.headline)
            if drillsViewModel.isLoadingRecommendations {
                ProgressView("Refreshing recommendations...")
            }
            if let date = drillsViewModel.cachedRecommendationsDate {
                Text("Saved recommendations as of \(date.formatted(date: .abbreviated, time: .shortened)). They may be out of date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = drillsViewModel.recommendationsError {
                Text(error).foregroundStyle(.secondary)
                Button("Retry Recommendations") {
                    Task { await drillsViewModel.loadRecommendations() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(drillsViewModel.isLoadingRecommendations)
            } else if !drillsViewModel.isLoadingRecommendations && drillsViewModel.recommendations.isEmpty {
                Text("No recommendations yet. Browse drills or learn the basics to find a starting point.")
                    .foregroundStyle(.secondary)
                Button("Browse All Drills", action: onBrowseAllDrills)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            ForEach(Array(drillsViewModel.recommendations.prefix(3))) { drill in
                Button {
                    selectedDrill = drill
                } label: {
                    dashboardLink(drill.title, detail: drill.category, icon: "figure.racquetball")
                }
                .buttonStyle(.plain)
            }
            NavigationLink("All Recommendations") {
                RecommendationsView(onBrowseAllDrills: onBrowseAllDrills)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding()
        .pickleballCard()
    }

    private func dashboardLink(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon).foregroundStyle(Color.neonCyan)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding()
        .pickleballCard()
        .contentShape(Rectangle())
    }
}

struct TrainingActivitySummary: View {
    @EnvironmentObject private var store: TrainingStreakStore
    @AppStorage("training.weeklyGoal") private var weeklyGoal = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.isLoading {
                ProgressView("Refreshing training activity...")
            }
            if store.hasHistory {
                // A vertical layout keeps both labels readable at accessibility sizes.
                Label("\(store.streakDays) day streak", systemImage: "flame.fill")
                    .font(.headline)
                Label("\(store.sessionsThisWeek) of \(max(1, weeklyGoal)) sessions this week", systemImage: "calendar")
                    .font(.headline)
                if store.sessionDates.isEmpty {
                    Text("No saved workouts yet. Your first session starts your training history.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let date = store.cachedDate {
                    Text("Saved activity as of \(date.formatted(date: .abbreviated, time: .shortened)). Counts may be out of date.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if !store.isLoading {
                Text("Training activity is unavailable.")
                    .foregroundStyle(.secondary)
            }
            if let error = store.errorMessage {
                Text(error).font(.subheadline).foregroundStyle(.secondary)
                Button("Retry Training Activity") {
                    Task { await store.load() }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(store.isLoading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrainingProgressView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TrainingActivitySummary()
                        .padding()
                        .pickleballCard()
                    NavigationLink {
                        WorkoutHistoryView(client: authViewModel.client)
                    } label: {
                        Label("Training History", systemImage: "clock.arrow.circlepath")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding()
                            .pickleballCard()
                    }
                    NavigationLink {
                        VideoReviewView()
                    } label: {
                        Label("Video Self-Review", systemImage: "video.fill")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding()
                            .pickleballCard()
                    }
                }
                .padding()
                .readableWidth()
            }
            .navigationTitle("Progress")
            .genieBrandIconToolbar()
            .background(Color.deepSpace)
        }
    }
}
