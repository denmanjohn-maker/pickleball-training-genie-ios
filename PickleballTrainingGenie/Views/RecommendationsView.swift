import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject var drillsViewModel: DrillsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedDrill: Drill?

    /// Jumps to the Drills tab from the empty state; supplied by MainTabView,
    /// which owns the section selection.
    let onBrowseAllDrills: () -> Void

    /// Below-3.0 players (rated, or estimated by the skill check; unrated
    /// counts as beginner) get a pointer to the Learn section.
    private var isBeginner: Bool {
        let user = authViewModel.currentUser
        let current = max(user?.singlesDUPR ?? 0, user?.doublesDUPR ?? 0)
        if current > 0 { return current < 3.0 }
        return SkillAssessment.load().map { $0.estimatedLevel < 3.0 } ?? true
    }

    var body: some View {
        NavigationStack {
            Group {
                if drillsViewModel.isLoadingRecommendations {
                    ProgressView("Loading your recommendations…")
                        .tint(.neonMagenta)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = drillsViewModel.recommendationsError {
                    ContentUnavailableView {
                        Label("No Recommendations", systemImage: "star.slash")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await drillsViewModel.loadRecommendations() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.neonMagenta)
                    }
                } else if drillsViewModel.recommendations.isEmpty {
                    ContentUnavailableView {
                        Label("No Recommendations Yet", systemImage: "star.circle")
                    } description: {
                        Text("Complete a few drills to get personalized recommendations based on your DUPR level.")
                    } actions: {
                        Button("Browse All Drills") {
                            onBrowseAllDrills()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.neonMagenta)

                        NavigationLink("Learn the Basics") {
                            LearnView()
                        }
                        .buttonStyle(.bordered)
                        .tint(.neonCyan)
                    }
                } else {
                    VStack(spacing: 0) {
                        if let savedAt = drillsViewModel.cachedRecommendationsDate {
                            HStack(spacing: 8) {
                                Image(systemName: "wifi.slash")
                                    .foregroundColor(.solarGold)
                                Text("Offline — showing recommendations saved \(savedAt.formatted(date: .abbreviated, time: .shortened)).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.solarGold.opacity(0.08))
                        }
                        if isBeginner {
                            LearnPromoCard()
                        }
                        List(drillsViewModel.recommendations) { drill in
                            DrillRowView(
                                drill: drill,
                                isCompleted: drillsViewModel.completedDrillIds.contains(drill.id)
                            )
                            .onTapGesture { selectedDrill = drill }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .readableWidth()
                        .background(Color.deepSpace)
                    }
                }
            }
            .navigationTitle("For You")
            .navigationBarTitleDisplayMode(.large)
            .genieBrandIconToolbar()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await drillsViewModel.loadRecommendations() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.neonCyan)
                    }
                }
            }
            .sheet(item: $selectedDrill) { drill in
                DrillDetailView(drill: drill)
                    .environmentObject(drillsViewModel)
            }
            .task {
                if drillsViewModel.recommendations.isEmpty {
                    await drillsViewModel.loadRecommendations()
                }
            }
            .safeAreaInset(edge: .top) {
                RecommendationsHeaderView()
            }
        }
    }
}

private struct LearnPromoCard: View {
    var body: some View {
        NavigationLink {
            LearnView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .font(.title3)
                    .foregroundColor(.solarGold)
                VStack(alignment: .leading, spacing: 4) {
                    Text("New to pickleball?")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("Rules, scoring, and the terms everyone keeps saying — all offline.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .pickleballCard()
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }
}

private struct RecommendationsHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Training Plan")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Drills matched to your DUPR level")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "figure.racquetball")
                    .font(.title)
                    .foregroundColor(.neonMagenta)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.cosmicPurple)
    }
}

#Preview {
    RecommendationsView(onBrowseAllDrills: {})
        .environmentObject(DrillsViewModel(client: PickleballTrainingGenieClient(
            baseURL: URL(string: "http://localhost:5123/")!
        )))
        .environmentObject(AuthViewModel())
}
