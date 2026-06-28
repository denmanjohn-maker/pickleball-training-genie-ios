import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogoutConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.courtBlue, Color.graphiteBlack],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            Image(systemName: "figure.racquetball")
                                .font(.system(size: 48))
                                .foregroundColor(.neonVolt)
                        }
                        .shadow(color: .courtBlue.opacity(0.4), radius: 12, x: 0, y: 6)

                        if let user = authViewModel.currentUser {
                            Text(user.email)
                                .font(.title3)
                                .fontWeight(.semibold)
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
                            colors: [Color.courtBlue.opacity(0.08), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // DUPR Info Card
                                        if let user = authViewModel.currentUser {
                                            VStack(spacing: 0) {
                                                if user.isDuprLinked {
                                                    HStack {
                                                        Text("Verified by DUPR")
                                                            .font(.caption)
                                                            .bold()
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(Color.blue)
                                                            .foregroundColor(.white)
                                                            .cornerRadius(8)
                                                    }
                                                    .padding()
                                                }

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
                                                    color: .pickleballGreen
                                                )

                                                if !user.isDuprLinked {
                                                    Divider().padding(.horizontal)
                                                    NavigationLink {
                                                        EditRatingsView()
                                                    } label: {
                                                        HStack {
                                                            Text("Edit Ratings")
                                                            Spacer()
                                                            Image(systemName: "chevron.right")
                                                                .foregroundColor(.gray)
                                                        }
                                                        .padding()
                                                    }
                                                }
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
                                color: .pickleballGreen
                            )
                        }
                        .pickleballCard()
                        .padding(.horizontal)
                    }

                    // About DUPR Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About DUPR", systemImage: "info.circle.fill")
                            .font(.headline)
                            .foregroundColor(.pickleballDarkGreen)

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
            .background(Color(.systemGroupedBackground))
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
        }
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
            Section("Current Ratings") {
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
                            ProgressView().tint(.white)
                        } else {
                            Text("Save Ratings")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .disabled(authViewModel.isLoading || !targetValid)
                .listRowBackground(Color.pickleballGreen)
                .foregroundColor(.white)
            }
        }
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
