import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var drillsViewModel: DrillsViewModel
    @State private var completedDrillIndices: Set<Int> = []
    @State private var showGuidedSession = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.neonMagenta.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.neonMagenta)
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
                            colors: [Color.neonMagenta.opacity(0.10), Color.neonCyan.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.neonCyan.opacity(0.25), lineWidth: 1.5)
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
                    .buttonStyle(PrimaryButtonStyle())
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
                        if let savedAt = drillsViewModel.cachedWorkoutDate {
                            HStack(spacing: 8) {
                                Image(systemName: "internaldrive.fill")
                                    .foregroundColor(.solarGold)
                                Text("Saved workout from \(savedAt.formatted(date: .abbreviated, time: .shortened)) — ready to run, no signal needed.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.solarGold.opacity(0.08))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }

                        // Guided session is the primary way to run the plan —
                        // the checklist below stays for players who self-pace.
                        // (Hidden for raw-text fallback plans with no drills.)
                        if !workout.drills.isEmpty {
                            Button {
                                showGuidedSession = true
                            } label: {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Start Guided Session")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle(color: .neonCyan))
                            .padding(.horizontal)
                            .fullScreenCover(isPresented: $showGuidedSession) {
                                GuidedSessionView(workout: workout)
                                    .environmentObject(drillsViewModel)
                            }
                        }

                        WorkoutResultView(workout: workout, completedDrillIndices: $completedDrillIndices)
                            .padding(.horizontal)

                        // Complete Workout
                        VStack(spacing: 8) {
                            Button {
                                Task {
                                    await drillsViewModel.completeWorkout(completedIndices: completedDrillIndices)
                                }
                            } label: {
                                HStack {
                                    if drillsViewModel.isCompletingWorkout {
                                        ProgressView().tint(.black)
                                    } else {
                                        Image(systemName: "checkmark.seal.fill")
                                    }
                                    Text(drillsViewModel.isCompletingWorkout
                                         ? "Saving Workout…"
                                         : "Complete Workout")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(drillsViewModel.isCompletingWorkout)

                            Text("Check off the drills you finished, then save it to your history.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.deepSpace)
            .onChange(of: drillsViewModel.workout?.drills.count) { _, _ in
                completedDrillIndices = []
            }
            .alert("Workout Saved! 💪", isPresented: $drillsViewModel.workoutCompletedSuccessfully) {
                Button("Nice!") {}
            } message: {
                Text("Your session was added to your training history. Check it out on the Profile tab.")
            }
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
                .foregroundColor(isSelected ? .black : .primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(isSelected ? Color.neonMagenta : Color(.systemGray5))
                .cornerRadius(10)
        }
    }
}

private struct WorkoutResultView: View {
    let workout: WorkoutPlanResponse
    @Binding var completedDrillIndices: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Your Workout Plan", systemImage: "list.bullet.clipboard.fill")
                    .font(.headline)
                    .foregroundColor(.starlight)
                Spacer()
                if let total = workout.totalDurationMinutes {
                    Text("\(total) min")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.neonCyan)
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
                        WorkoutDrillCard(
                            index: index + 1,
                            item: item,
                            isCompleted: completedDrillIndices.contains(index)
                        ) {
                            if completedDrillIndices.contains(index) {
                                completedDrillIndices.remove(index)
                            } else {
                                completedDrillIndices.insert(index)
                            }
                        }
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
                    .background(Color.nebulaSurface)
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
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color.neonCyan)
                    .frame(width: 28, height: 28)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundColor(.black)
                } else {
                    Text("\(index)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .strikethrough(isCompleted, color: .secondary)
                    Spacer()
                    Text("\(item.durationMinutes)m")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.neonCyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.neonCyan.opacity(0.1))
                        .cornerRadius(6)
                }
                CategoryBadge(category: item.category)
                Text(item.coachingNotes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }

            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.nebulaSurface)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

#Preview {
    WorkoutView()
        .environmentObject(DrillsViewModel(client: PickleballTrainingGenieClient(
            baseURL: URL(string: "http://localhost:5123/")!
        )))
}
