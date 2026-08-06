import SwiftUI

struct DrillsListView: View {
    @EnvironmentObject var drillsViewModel: DrillsViewModel
    @ObservedObject private var favorites = FavoriteDrills.shared
    @State private var searchText = ""
    @State private var selectedDrill: Drill?
    @State private var showFavoritesOnly = false

    var displayedDrills: [Drill] {
        var filtered = drillsViewModel.filteredDrills
        if showFavoritesOnly {
            filtered = filtered.filter { favorites.contains($0.id) }
        }
        if searchText.isEmpty { return filtered }
        return filtered.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.description.localizedCaseInsensitiveContains(searchText)
                || $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Favorites first — the player's own shortlist.
                        FilterChip(
                            label: "♥ Favorites",
                            isSelected: showFavoritesOnly
                        ) {
                            showFavoritesOnly.toggle()
                        }
                        // Category filters
                        FilterChip(
                            label: "All",
                            isSelected: drillsViewModel.selectedCategory == nil && !showFavoritesOnly
                        ) {
                            drillsViewModel.selectedCategory = nil
                            showFavoritesOnly = false
                        }
                        ForEach(drillsViewModel.drillCategories, id: \.self) { category in
                            FilterChip(
                                label: category,
                                isSelected: drillsViewModel.selectedCategory == category
                            ) {
                                drillsViewModel.selectedCategory =
                                    drillsViewModel.selectedCategory == category ? nil : category
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color.deepSpace)

                // DUPR Level filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: "All Levels",
                            isSelected: drillsViewModel.selectedLevel == nil
                        ) {
                            drillsViewModel.selectedLevel = nil
                        }
                        ForEach(SkillLevel.allCases) { level in
                            FilterChip(
                                label: "\(level.shortLabel) \(level.name)",
                                isSelected: drillsViewModel.selectedLevel == level.value
                            ) {
                                drillsViewModel.selectedLevel =
                                    drillsViewModel.selectedLevel == level.value ? nil : level.value
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                .background(Color.deepSpace)

                Divider()

                if drillsViewModel.isLoadingDrills {
                    ProgressView("Loading drills…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tint(.neonMagenta)
                } else if let error = drillsViewModel.drillsError {
                    ContentUnavailableView {
                        Label("Could Not Load Drills", systemImage: "wifi.slash")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await drillsViewModel.loadDrills() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.neonMagenta)
                    }
                } else if displayedDrills.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    if let cachedDate = drillsViewModel.cachedDrillsDate {
                        OfflineBanner(savedAt: cachedDate)
                    }
                    if let notice = drillsViewModel.levelFallbackNotice {
                        LevelFallbackBanner(
                            requested: notice.requested,
                            showing: notice.showing
                        )
                    }
                    List(displayedDrills) { drill in
                        DrillRowView(drill: drill, isCompleted: drillsViewModel.completedDrillIds.contains(drill.id))
                            .onTapGesture { selectedDrill = drill }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.deepSpace)
                }
            }
            .navigationTitle("Drills")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        LearnView()
                    } label: {
                        Label("Learn", systemImage: "book.fill")
                            .foregroundColor(.solarGold)
                    }
                    .accessibilityLabel("Learn the rules and fundamentals")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await drillsViewModel.loadDrills() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.neonCyan)
                    }
                    .accessibilityLabel("Refresh drills")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    GenieBrandIcon()
                }
            }
            .searchable(text: $searchText, prompt: "Search drills…")
            .sheet(item: $selectedDrill) { drill in
                DrillDetailView(drill: drill)
                    .environmentObject(drillsViewModel)
            }
            .task {
                if drillsViewModel.drills.isEmpty {
                    await drillsViewModel.loadDrills()
                }
            }
        }
    }

}

/// Shown when the network failed and the list is serving the last good fetch.
private struct OfflineBanner: View {
    let savedAt: Date

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.solarGold)
            Text("Offline — showing drills saved \(savedAt.formatted(date: .abbreviated, time: .shortened)).")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.solarGold.opacity(0.08))
    }
}

/// Shown when the selected level has no drills yet and the list is
/// substituting the nearest populated level.
private struct LevelFallbackBanner: View {
    let requested: Decimal
    let showing: Decimal

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.neonCyan)
            Text("No \(requested.duprString()) drills yet — showing the closest level (\(showing.duprString())).")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.neonCyan.opacity(0.08))
    }
}

struct DrillRowView: View {
    let drill: Drill
    let isCompleted: Bool
    @ObservedObject private var favorites = FavoriteDrills.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(drill.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        CategoryBadge(category: drill.category)
                        DUPRBadge(level: drill.targetDUPRLevel)
                    }
                }

                Spacer()

                if favorites.contains(drill.id) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.neonMagenta)
                        .font(.caption)
                }
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.neonCyan)
                        .font(.title3)
                }
            }

            Text(drill.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if drill.videoUrl != nil {
                Label("Video Available", systemImage: "play.circle.fill")
                    .font(.caption)
                    .foregroundColor(.neonCyan)
            }
        }
        .padding()
        .pickleballCard()
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .black : .primary)
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(isSelected ? Color.neonMagenta : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
}

#Preview {
    DrillsListView()
        .environmentObject(DrillsViewModel(client: PickleballTrainingGenieClient(
            baseURL: URL(string: "http://localhost:5123/")!
        )))
}
