import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogoutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showDeleteError = false
    @State private var showEditRatings = false
    @State private var showEditProfile = false
    @State private var showAvatarPicker = false
    @State private var showTutorial = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        Button {
                            showAvatarPicker = true
                        } label: {
                            AvatarView(
                                avatarId: authViewModel.currentUser?.avatarId,
                                customImage: authViewModel.avatarImage,
                                size: 100
                            )
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white, Color.neonMagenta)
                            }
                        }
                        .buttonStyle(.plain)

                        if let user = authViewModel.currentUser {
                            VStack(spacing: 4) {
                                Text(user.displayName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                if user.displayName != user.email {
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let cityName = user.homeCityName {
                                    Label(cityName, systemImage: "mappin.and.ellipse")
                                        .font(.caption)
                                        .foregroundColor(.neonCyan)
                                }
                            }
                        } else {
                            Text("Pickleball Player")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .background(
                        LinearGradient(
                            colors: [Color.cosmicPurple.opacity(0.18), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // DUPR Info Card
                                        if let user = authViewModel.currentUser {
                                            VStack(spacing: 0) {
                                                DUPRStatRow(
                                                    title: "Singles DUPR",
                                                    level: user.singlesDUPR ?? 0.0,
                                                    icon: "person.fill",
                                                    color: .blue
                                                )
                                                Divider().padding(.horizontal)
                                                DUPRStatRow(
                                                    title: "Doubles DUPR",
                                                    level: user.doublesDUPR ?? 0.0,
                                                    icon: "person.2.fill",
                                                    color: .purple
                                                )
                                                Divider().padding(.horizontal)
                                                DUPRStatRow(
                                                    title: "Target DUPR",
                                                    level: user.targetDUPR,
                                                    icon: "target",
                                                    color: .neonCyan
                                                )

                                                Divider().padding(.horizontal)
                                                Button {
                                                    showEditRatings = true
                                                } label: {
                                                    HStack {
                                                        Image(systemName: "pencil.circle.fill")
                                                            .foregroundColor(.neonCyan)
                                                        Text("Edit My Ratings")
                                                            .fontWeight(.medium)
                                                        Spacer()
                                                        Image(systemName: "chevron.right")
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    .padding()
                                                }
                                                .foregroundColor(.primary)
                                            }
                                            .pickleballCard()
                                            .padding(.horizontal)
                                        } else {
                        // Placeholder stats
                        VStack(spacing: 0) {
                            StatRowPlaceholder(
                                title: "Current DUPR",
                                icon: "chart.bar.fill",
                                color: .blue
                            )
                            Divider().padding(.horizontal)
                            StatRowPlaceholder(
                                title: "Target DUPR",
                                icon: "target",
                                color: .neonCyan
                            )
                        }
                        .pickleballCard()
                        .padding(.horizontal)
                    }

                    // Training + Profile actions
                    VStack(spacing: 0) {
                        NavigationLink {
                            WorkoutHistoryView(client: authViewModel.client)
                                .environmentObject(authViewModel)
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.neonMagenta)
                                    .frame(width: 28)
                                Text("Training History")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        .foregroundColor(.primary)

                        Divider().padding(.horizontal)

                        NavigationLink {
                            VideoReviewView()
                        } label: {
                            HStack {
                                Image(systemName: "video.fill")
                                    .foregroundColor(.solarGold)
                                    .frame(width: 28)
                                Text("Video Self-Review")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        .foregroundColor(.primary)

                        Divider().padding(.horizontal)

                        Button {
                            showEditProfile = true
                        } label: {
                            HStack {
                                Image(systemName: "person.text.rectangle.fill")
                                    .foregroundColor(.neonCyan)
                                    .frame(width: 28)
                                Text("Edit Profile")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        .foregroundColor(.primary)

                        Divider().padding(.horizontal)

                        Button {
                            showTutorial = true
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundColor(.solarGold)
                                    .frame(width: 28)
                                Text("App Tutorial")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        .foregroundColor(.primary)
                    }
                    .pickleballCard()
                    .padding(.horizontal)

                    // Training habits — weekly goal + reminders
                    TrainingHabitsCard()
                        .padding(.horizontal)

                    // Player details
                    if let user = authViewModel.currentUser, hasPlayerDetails(user) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Player Details", systemImage: "figure.pickleball")
                                .font(.headline)
                                .foregroundColor(.starlight)

                            if let hand = user.dominantHand {
                                ProfileDetailRow(icon: "hand.raised.fill", title: "Dominant Hand", value: hand.capitalized)
                            }
                            if let style = user.preferredPlayStyle {
                                ProfileDetailRow(icon: "person.2.fill", title: "Play Style", value: style.capitalized)
                            }
                            if let years = user.yearsPlaying {
                                ProfileDetailRow(
                                    icon: "calendar",
                                    title: "Years Playing",
                                    value: years == 0 ? "Less than a year" : "\(years)"
                                )
                            }
                            if let duration = user.preferredSessionDurationMinutes {
                                ProfileDetailRow(icon: "timer", title: "Preferred Session", value: "\(duration) min")
                            }
                        }
                        .padding()
                        .pickleballCard()
                        .padding(.horizontal)
                    }

                    // About DUPR Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About DUPR", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundColor(.starlight)

                        ForEach(SkillLevel.allCases) { level in
                            HStack(alignment: .top, spacing: 12) {
                                Text(level.shortLabel)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 36)
                                    .padding(.vertical, 3)
                                    .background(level.color)
                                    .cornerRadius(6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.name)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(level.summary)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .pickleballCard()
                    .padding(.horizontal)

                    // Legal & Support
                    VStack(spacing: 0) {
                        externalLinkRow("Privacy Policy", systemImage: "hand.raised.fill", url: AppLinks.privacyPolicy)
                        Divider().overlay(Color.starlight.opacity(0.15))
                        externalLinkRow("Support", systemImage: "lifepreserver.fill", url: AppLinks.support)
                    }
                    .padding(.vertical, 4)
                    .pickleballCard()
                    .padding(.horizontal)

                    // App Info
                    VStack(spacing: 4) {
                        Text("Pickleball Training Genie")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(AppInfo.versionString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Account actions
                    Button {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(authViewModel.isLoading)
                    .padding(.horizontal)

                    // Delete Account — permanent; required for App Store (Guideline 5.1.1(v))
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "trash")
                            }
                            Text("Delete Account")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(authViewModel.isLoading)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.deepSpace)
            .confirmationDialog(
                "Sign out of Pickleball Genie?",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    authViewModel.logout()
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Delete your account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        let success = await authViewModel.deleteAccount()
                        if !success { showDeleteError = true }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and all your data — profile, ratings, and workout history. This can't be undone.")
            }
            .alert("Couldn't Delete Account", isPresented: $showDeleteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authViewModel.errorMessage ?? "Something went wrong. Please try again.")
            }
            .sheet(isPresented: $showEditRatings) {
                NavigationStack {
                    EditRatingsView()
                        .environmentObject(authViewModel)
                        .navigationTitle("Edit Ratings")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showEditRatings = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                NavigationStack {
                    EditProfileView()
                        .environmentObject(authViewModel)
                        .navigationTitle("Edit Profile")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showEditProfile = false }
                            }
                        }
                }
            }
            .fullScreenCover(isPresented: $showTutorial) {
                AppTutorialView(onComplete: { showTutorial = false })
            }
            .sheet(isPresented: $showAvatarPicker) {
                NavigationStack {
                    AvatarPickerSheet()
                        .environmentObject(authViewModel)
                        .navigationTitle("Choose Avatar")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showAvatarPicker = false }
                            }
                        }
                }
            }
        }
    }

    private func externalLinkRow(_ title: String, systemImage: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline)
                    .foregroundColor(.starlight)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.footnote)
                    .foregroundColor(.neonCyan)
            }
            .contentShape(Rectangle())
            .padding(.horizontal)
            .frame(minHeight: 44)
        }
    }

    private func hasPlayerDetails(_ user: User) -> Bool {
        user.dominantHand != nil || user.preferredPlayStyle != nil
            || user.yearsPlaying != nil || user.preferredSessionDurationMinutes != nil
    }

}

/// Weekly training goal and local reminder notifications. All state is
/// on-device: goal in UserDefaults, reminders via UNUserNotificationCenter.
private struct TrainingHabitsCard: View {
    @State private var weeklyGoal = TrainingStats.weeklyGoal
    @State private var remindersEnabled = TrainingReminders.isEnabled
    @State private var selectedWeekdays = TrainingReminders.savedWeekdays
    @State private var reminderTime = TrainingHabitsCard.initialTime
    @State private var showPermissionDenied = false

    // 1 = Sunday … 7 = Saturday, matching DateComponents.weekday.
    private static let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private static var initialTime: Date {
        let saved = TrainingReminders.savedTime
        return Calendar.current.date(
            bySettingHour: saved.hour, minute: saved.minute, second: 0, of: Date()
        ) ?? Date()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Training Habits", systemImage: "flame.fill")
                .font(.headline)
                .foregroundColor(.starlight)

            Stepper(value: $weeklyGoal, in: 1...14) {
                HStack {
                    Text("Weekly goal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(weeklyGoal) session\(weeklyGoal == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            .onChange(of: weeklyGoal) { _, newValue in
                TrainingStats.weeklyGoal = newValue
            }

            Divider()

            Toggle(isOn: $remindersEnabled) {
                Text("Training reminders")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .tint(.neonMagenta)
            .onChange(of: remindersEnabled) { _, isOn in
                Task { @MainActor in
                    if isOn {
                        let allowed = await TrainingReminders.requestAuthorization()
                        if !allowed {
                            remindersEnabled = false
                            showPermissionDenied = true
                            return
                        }
                    }
                    // Persist the captured value, not current state — the
                    // toggle may have flipped again while authorization was
                    // in flight (each flip runs its own task).
                    TrainingReminders.isEnabled = isOn
                    await TrainingReminders.reschedule()
                }
            }

            if remindersEnabled {
                HStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { weekday in
                        let isOn = selectedWeekdays.contains(weekday)
                        Button {
                            if isOn {
                                selectedWeekdays.remove(weekday)
                            } else {
                                selectedWeekdays.insert(weekday)
                            }
                        } label: {
                            Text(Self.weekdayLabels[weekday - 1])
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(isOn ? .black : .secondary)
                                .frame(width: 32, height: 32)
                                .background(isOn ? Color.neonMagenta : Color(.systemGray5))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(accessibilityName(for: weekday))
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .onChange(of: selectedWeekdays) { _, newValue in
                    TrainingReminders.savedWeekdays = newValue
                    Task { await TrainingReminders.reschedule() }
                }

                DatePicker(
                    "Reminder time",
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
                .onChange(of: reminderTime) { _, newValue in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    TrainingReminders.savedTime = (components.hour ?? 17, components.minute ?? 0)
                    Task { await TrainingReminders.reschedule() }
                }
            }
        }
        .padding()
        .pickleballCard()
        .alert("Notifications Are Off", isPresented: $showPermissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable notifications for Pickleball Genie in Settings to get training reminders.")
        }
    }

    private func accessibilityName(for weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }
}

private struct DUPRStatRow: View {
    let title: String
    let level: Decimal
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            DUPRBadge(level: level)
        }
        .padding()
    }
}

private struct ProfileDetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.neonCyan)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

private struct StatRowPlaceholder: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("—")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
struct EditRatingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var singlesDUPR: Decimal = 3.0
    @State private var doublesDUPR: Decimal = 3.0
    @State private var targetDUPR: Decimal = 3.5
    @State private var showSkillCheck = false

    var currentDUPR: Decimal { max(singlesDUPR, doublesDUPR) }
    var targetValid: Bool { targetDUPR >= currentDUPR }

    var body: some View {
        Form {
            Section {
                Button {
                    showSkillCheck = true
                } label: {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.neonMagenta)
                        Text("Not sure? Take the 60-second skill check")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .foregroundColor(.primary)
            }

            Section {
                SkillLevelPicker(title: "Singles DUPR", selection: $singlesDUPR)
                    .padding(.vertical, 4)

                SkillLevelPicker(title: "Doubles DUPR", selection: $doublesDUPR)
                    .padding(.vertical, 4)
            } header: {
                Text("Current Ratings")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    SkillLevelPicker(title: "Target DUPR", selection: $targetDUPR)

                    if !targetValid {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Target must be ≥ current DUPR")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Goal")
            } footer: {
                Text("Your target DUPR determines the drills the AI selects for your workouts.")
            }

            if let error = authViewModel.errorMessage {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }

            Section {
                Button {
                    Task {
                        authViewModel.errorMessage = nil
                        await authViewModel.updateRatings(
                            singles: singlesDUPR,
                            doubles: doublesDUPR,
                            target: targetDUPR
                        )
                        if authViewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if authViewModel.isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("Save Ratings")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .disabled(authViewModel.isLoading || !targetValid)
                .listRowBackground(Color.neonMagenta)
                .foregroundColor(.black)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.deepSpace)
        .navigationTitle("Edit Ratings")
        .onAppear {
            if let user = authViewModel.currentUser {
                singlesDUPR = user.singlesDUPR ?? 3.0
                doublesDUPR = user.doublesDUPR ?? 3.0
                targetDUPR = user.targetDUPR
            }
        }
        .sheet(isPresented: $showSkillCheck) {
            SkillAssessmentView { result in
                let level = Decimal(result.estimatedLevel)
                singlesDUPR = level
                doublesDUPR = level
                targetDUPR = SkillLevel.nearest(to: level).nextUp.value
                showSkillCheck = false
            }
        }
    }
}
