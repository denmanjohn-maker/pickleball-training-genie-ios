import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var registrationSuccess = false

    var passwordsMatch: Bool { password == confirmPassword }
    var formValid: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6 && passwordsMatch
    }

    var body: some View {
        ZStack {
            SynthwaveGradient()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.neonMagenta)
                        Text("Create Account")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Create your account, then set up your player profile")
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
                                    singlesDUPR: nil,
                                    doublesDUPR: nil,
                                    targetDUPR: 0
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

                        // Social sign-in (Apple + Google) — first sign-in creates the account
                        SocialSignInButtons()
                    }
                    .padding(24)
                    .background(Color.nebulaSurface)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.neonMagenta.opacity(0.55), .neonCyan.opacity(0.55)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .neonMagenta.opacity(0.2), radius: 12, x: 0, y: 6)
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
            Button("Set Up My Profile") {
                let registeredEmail = email
                let registeredPassword = password
                // Clear sensitive fields before async login
                email = ""
                password = ""
                confirmPassword = ""
                Task {
                    await authViewModel.login(email: registeredEmail, password: registeredPassword)
                }
            }
        } message: {
            Text("Next, tell us about your game so the genie can build your training plan.")
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
