import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var currentDUPR: Decimal = 3.0
    @State private var targetDUPR: Decimal = 3.5
    @State private var registrationSuccess = false

    let duprOptions: [(Decimal, String)] = [
        (3.0, "3.0 – Beginner"),
        (3.5, "3.5 – Intermediate"),
        (4.0, "4.0 – Advanced"),
        (5.0, "5.0 – Professional")
    ]

    var passwordsMatch: Bool { password == confirmPassword }
    var formValid: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6
            && passwordsMatch && targetDUPR >= currentDUPR
    }

    var body: some View {
        ZStack {
            PickleballGradient()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.pickleballYellow)
                        Text("Create Account")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Set your DUPR level and start improving")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Form Card
                    VStack(spacing: 20) {
                        // Email
                        FieldLabel(icon: "envelope.fill", title: "Email") {
                            TextField("your@email.com", text: $email)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                        }

                        // Password
                        FieldLabel(icon: "lock.fill", title: "Password") {
                            SecureField("At least 6 characters", text: $password)
                                .textContentType(.newPassword)
                        }

                        // Confirm Password
                        FieldLabel(icon: "lock.shield.fill", title: "Confirm Password") {
                            SecureField("Repeat your password", text: $confirmPassword)
                                .textContentType(.newPassword)
                        }

                        if !confirmPassword.isEmpty && !passwordsMatch {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Passwords don't match")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        Divider()

                        // DUPR Section
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Your DUPR Level", systemImage: "chart.bar.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.pickleballDarkGreen)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Current DUPR")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Picker("Current DUPR", selection: $currentDUPR) {
                                    ForEach(duprOptions, id: \.0) { value, label in
                                        Text(label).tag(value)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            VStack(alignment: .leading, spacing: 6) {
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
                            }

                            if targetDUPR < currentDUPR {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Target must be ≥ current DUPR")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        if let error = authViewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        Button {
                            Task {
                                let success = await authViewModel.register(
                                    email: email,
                                    password: password,
                                    currentDUPR: currentDUPR,
                                    targetDUPR: targetDUPR
                                )
                                if success {
                                    registrationSuccess = true
                                }
                            }
                        } label: {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView().tint(.black)
                                }
                                Text(authViewModel.isLoading ? "Creating Account…" : "Create Account")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!formValid || authViewModel.isLoading)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
                    .padding(.horizontal, 20)

                    Button { dismiss() } label: {
                        Text("Already have an account? **Sign In**")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Account Created! 🎉", isPresented: $registrationSuccess) {
            Button("Sign In Now") {
                Task {
                    await authViewModel.login(email: email, password: password)
                }
            }
        } message: {
            Text("Your account has been created. Sign in to start training!")
        }
    }
}

private struct FieldLabel<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            content
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
