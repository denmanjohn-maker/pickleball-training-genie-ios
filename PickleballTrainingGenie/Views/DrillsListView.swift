import SwiftUI

struct DrillsListView: View {
    @EnvironmentObject var drillsViewModel: DrillsViewModel
    @State private var searchText = ""
    @State private var selectedDrill: Drill?

    var displayedDrills: [Drill] {
        let filtered = drillsViewModel.filteredDrills
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
                        // Category filters
                        FilterChip(
                            label: "All",
                            isSelected: drillsViewModel.selectedCategory == nil
                        ) {
                            drillsViewModel.selectedCategory = nil
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
                .background(Color(.systemBackground))

                // DUPR Level filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(
                            label: "All Levels",
                            isSelected: drillsViewModel.selectedLevel == nil
                        ) {
                            drillsViewModel.selectedLevel = nil
                        }
                        ForEach(drillsViewModel.duprLevels, id: \.self) { level in
                            FilterChip(
                                label: duprLabel(level),
                                isSelected: drillsViewModel.selectedLevel == level
                            ) {
                                drillsViewModel.selectedLevel =
                                    drillsViewModel.selectedLevel == level ? nil : level
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                .background(Color(.systemBackground))

                Divider()

                if drillsViewModel.isLoadingDrills {
                    ProgressView("Loading drills…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tint(.neonVolt)
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
                        .tint(.neonVolt)
                    }
                } else if displayedDrills.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(displayedDrills) { drill in
                        DrillRowView(drill: drill, isCompleted: drillsViewModel.completedDrillIds.contains(drill.id))
                            .onTapGesture { selectedDrill = drill }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Drills")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await drillsViewModel.loadDrills() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.pickleballGreen)
                    }
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

    private func duprLabel(_ level: Decimal) -> String {
        switch level {
        case 5.0...: return "5.0 Pro"
        case 4.0..<5.0: return "4.0 Advanced"
        case 3.5..<4.0: return "3.5 Intermediate"
        default: return "3.0 Beginner"
        }
    }
}

struct DrillRowView: View {
    let drill: Drill
    let isCompleted: Bool

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

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.pickleballGreen)
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
                    .foregroundColor(.pickleballGreen)
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
                .background(isSelected ? Color.neonVolt : Color(.systemGray5))
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
