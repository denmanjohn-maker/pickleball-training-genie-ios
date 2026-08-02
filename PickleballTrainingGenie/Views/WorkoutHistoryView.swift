import SwiftUI

/// Training history: completed workout sessions and mastered drills in one timeline.
struct WorkoutHistoryView: View {
    @StateObject private var viewModel: WorkoutHistoryViewModel

    init(client: PickleballTrainingGenieClient) {
        _viewModel = StateObject(wrappedValue: WorkoutHistoryViewModel(client: client))
    }

    var body: some View {
        HistoryListView(viewModel: viewModel)
    }
}

private struct HistoryListView: View {
    @ObservedObject var viewModel: WorkoutHistoryViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.timeline.isEmpty {
                ProgressView("Loading your history…")
                    .tint(.neonMagenta)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage, viewModel.timeline.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't Load History", systemImage: "wifi.slash")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.neonMagenta)
                }
            } else if viewModel.timeline.isEmpty {
                ContentUnavailableView {
                    Label("No Workouts Yet", systemImage: "figure.racquetball")
                } description: {
                    Text("Generate a workout on the Workout tab and tap \"Complete Workout\" to start building your history.")
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        statsHeader

                        ForEach(viewModel.timeline) { entry in
                            switch entry {
                            case .workout(let session):
                                WorkoutSessionCard(session: session)
                            case .drill(let item):
                                DrillCompletionCard(item: item)
                            }
                        }

                        if viewModel.hasMoreSessions {
                            Button {
                                Task { await viewModel.loadMore() }
                            } label: {
                                if viewModel.isLoadingMore {
                                    ProgressView().tint(.neonMagenta)
                                } else {
                                    Text("Load More")
                                        .font(.subheadline)
                                        .foregroundColor(.neonMagenta)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.load()
                }
            }
        }
        .background(Color.deepSpace)
        .navigationTitle("Training History")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if viewModel.timeline.isEmpty {
                await viewModel.load()
            }
        }
    }

    private var statsHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                HistoryStatCard(
                    value: "\(viewModel.totalSessionCount)",
                    label: "Workouts",
                    icon: "bolt.fill",
                    color: .neonMagenta
                )
                HistoryStatCard(
                    value: "\(viewModel.totalMinutesTrained)",
                    label: "Minutes",
                    icon: "timer",
                    color: .neonCyan
                )
                HistoryStatCard(
                    value: "\(viewModel.drillsMasteredCount)",
                    label: "Drills Mastered",
                    icon: "checkmark.seal.fill",
                    color: .solarGold
                )
            }
            HStack(spacing: 12) {
                HistoryStatCard(
                    value: "\(viewModel.currentStreakDays)",
                    label: "Day Streak",
                    icon: "flame.fill",
                    color: .orange
                )
                HistoryStatCard(
                    value: "\(viewModel.sessionsThisWeek)/\(TrainingStats.weeklyGoal)",
                    label: "This Week",
                    icon: "calendar",
                    color: .green
                )
            }
        }
    }
}

private struct HistoryStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .pickleballCard()
    }
}

private struct WorkoutSessionCard: View {
    let session: WorkoutSessionResponse
    @State private var isExpanded = false

    private var completedCount: Int {
        session.drills.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.neonMagenta.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.neonMagenta)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workout Session")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text(APIDateParsing.display(session.completedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 10) {
                            Label("\(session.durationMinutes) min", systemImage: "timer")
                            Label("\(completedCount)/\(session.drills.count) drills", systemImage: "checkmark.circle")
                        }
                        .font(.caption)
                        .foregroundColor(.neonCyan)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    ForEach(session.drills) { drill in
                        HStack(spacing: 10) {
                            Image(systemName: drill.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(drill.isCompleted ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(drill.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("\(drill.category) · \(drill.durationMinutes)m")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .pickleballCard()
    }
}

private struct DrillCompletionCard: View {
    let item: DrillProgressItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.solarGold.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.solarGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: 8) {
                    CategoryBadge(category: item.category)
                    Text("Mastered")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.solarGold)
                }
                if let completedAt = item.completedAt {
                    Text(APIDateParsing.display(completedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .pickleballCard()
    }
}
