import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogoutConfirmation = false
    @State private var showEditRatings = false
    @State private var showEditProfile = false
    @State private var showAvatarPicker = false

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
                    }
                    .pickleballCard()
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

                        ForEach(duprInfo, id: \.level) { info in
                            HStack(alignment: .top, spacing: 12) {
                                Text(info.level)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(width: 36)
                                    .padding(.vertical, 3)
                                    .background(info.color)
                                    .cornerRadius(6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(info.title)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(info.description)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .pickleballCard()
                    .padding(.horizontal)

                    // App Info
                    VStack(spacing: 4) {
                        Text("Pickleball Training Genie")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("Version 1.0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Logout
                    Button {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
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

    private func hasPlayerDetails(_ user: User) -> Bool {
        user.dominantHand != nil || user.preferredPlayStyle != nil
            || user.yearsPlaying != nil || user.preferredSessionDurationMinutes != nil
    }

    private var duprInfo: [(level: String, title: String, description: String, color: Color)] {
        [
            ("3.0", "Beginner", "Learning basic strokes, court positioning", .blue),
            ("3.5", "Intermediate", "Third shot drop, kitchen game, transitions", .orange),
            ("4.0", "Advanced", "Pattern recognition, speed-up/reset sequences", .red),
            ("5.0", "Pro", "ATP, Erne, tournament-level tactics", .purple)
        ]
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

    let duprOptions: [(Decimal, String)] = [
        (3.0, "3.0 – Beginner"),
        (3.5, "3.5 – Intermediate"),
        (4.0, "4.0 – Advanced"),
        (5.0, "5.0 – Professional")
    ]

    var currentDUPR: Decimal { max(singlesDUPR, doublesDUPR) }
    var targetValid: Bool { targetDUPR >= currentDUPR }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Singles DUPR")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Picker("Singles DUPR", selection: $singlesDUPR) {
                        ForEach(duprOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Doubles DUPR")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Picker("Doubles DUPR", selection: $doublesDUPR) {
                        ForEach(duprOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Current Ratings")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target DUPR")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Picker("Target DUPR", selection: $targetDUPR) {
                        ForEach(duprOptions, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

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
    }
}
