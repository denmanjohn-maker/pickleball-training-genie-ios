import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var drillsViewModel: DrillsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.pickleballYellow.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.pickleballYellow)
                        }

                        Text("AI Workout Generator")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Get a personalized drill sequence crafted by AI based on your DUPR level and goals.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.pickleballGreen.opacity(0.08), Color.pickleballYellow.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.pickleballGreen.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    // Duration Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Session Duration", systemImage: "timer")
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack(spacing: 10) {
                            ForEach([15, 30, 45, 60], id: \.self) { minutes in
                                DurationButton(
                                    minutes: minutes,
                                    isSelected: drillsViewModel.workoutDuration == minutes
                                ) {
                                    drillsViewModel.workoutDuration = minutes
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Generate Button
                    Button {
                        Task { await drillsViewModel.generateWorkout() }
                    } label: {
                        HStack {
                            if drillsViewModel.isGeneratingWorkout {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text(drillsViewModel.isGeneratingWorkout
                                 ? "Generating Workout…"
                                 : "Generate My Workout")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .pickleballYellow))
                    .disabled(drillsViewModel.isGeneratingWorkout)
                    .padding(.horizontal)

                    if let error = drillsViewModel.workoutError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Workout Results
                    if let workout = drillsViewModel.workout {
                        WorkoutResultView(workout: workout)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
    }
}

private struct DurationButton: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(minutes)m")
                .font(.subheadline)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.pickleballGreen : Color(.systemGray5))
                .cornerRadius(10)
        }
    }
}

private struct WorkoutResultView: View {
    let workout: WorkoutPlanResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Your Workout Plan", systemImage: "list.bullet.clipboard.fill")
                    .font(.headline)
                    .foregroundColor(.pickleballDarkGreen)
                Spacer()
                if let total = workout.totalDurationMinutes {
                    Text("\(total) min")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.pickleballGreen)
                }
            }

            // Warm-up
            if let warmup = workout.warmup, !warmup.isEmpty {
                WorkoutSectionCard(
                    icon: "flame.fill",
                    title: "Warm-Up",
                    content: warmup,
                    color: .orange
                )
            }

            // Drills
            if !workout.drills.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Drills", systemImage: "figure.racquetball")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ForEach(Array(workout.drills.enumerated()), id: \.element.id) { index, item in
                        WorkoutDrillCard(index: index + 1, item: item)
                    }
                }
            }

            // Cool-down
            if let cooldown = workout.cooldown, !cooldown.isEmpty {
                WorkoutSectionCard(
                    icon: "snowflake",
                    title: "Cool-Down",
                    content: cooldown,
                    color: .blue
                )
            }

            // Raw fallback
            if workout.drills.isEmpty, let raw = workout.rawResponse {
                Text(raw)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
        .padding()
        .pickleballCard()
    }
}

private struct WorkoutSectionCard: View {
    let icon: String
    let title: String
    let content: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(color.opacity(0.06))
        .cornerRadius(12)
    }
}

private struct WorkoutDrillCard: View {
    let index: Int
    let item: WorkoutDrillItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.pickleballGreen)
                    .frame(width: 28, height: 28)
                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(item.durationMinutes)m")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.pickleballGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.pickleballGreen.opacity(0.1))
                        .cornerRadius(6)
                }
                CategoryBadge(category: item.category)
                Text(item.coachingNotes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    WorkoutView()
        .environmentObject(DrillsViewModel(client: PickleballTrainingGenieClient(
            baseURL: URL(string: "http://localhost:5123/")!
        )))
}
