import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ZStack {
                SynthwaveGradient()
                StarFieldView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image("Logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [.neonMagenta, .neonCyan],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .neonGlow(.neonMagenta, radius: 14)

                            Text("Pickleball Genie")
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.neonMagenta, .neonCyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .neonGlow(.neonMagenta, radius: 8)

                            Text("Your AI-powered training coach")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.top, 40)

                        // Form Card
                        VStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Email", systemImage: "envelope.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                TextField("your@email.com", text: $email)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Password", systemImage: "lock.fill")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                SecureField("Password", text: $password)
                                    .textContentType(.password)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }

                            if let error = authViewModel.errorMessage {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                                .padding(.horizontal)
                            }

                            Button {
                                Task {
                                    await authViewModel.login(email: email, password: password)
                                }
                            } label: {
                                HStack {
                                    if authViewModel.isLoading {
                                        ProgressView()
                                            .tint(.black)
                                    }
                                    Text(authViewModel.isLoading ? "Signing In…" : "Sign In")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(authViewModel.isLoading || email.isEmpty || password.isEmpty)

                            // Social sign-in
                            HStack {
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 1)
                                Text("or continue with")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize()
                                Rectangle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 1)
                            }

                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                Task { await authViewModel.handleAppleSignIn(result) }
                            }
                            .signInWithAppleButtonStyle(.white)
                            .frame(height: 48)
                            .cornerRadius(12)

                            Button {
                                Task { await authViewModel.signInWithGoogle() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "g.circle.fill")
                                        .font(.title3)
                                    Text("Sign in with Google")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            .disabled(authViewModel.isLoading)

                            Button {
                                showRegister = true
                            } label: {
                                Text("New to Pickleball Genie? **Create Account**")
                                    .font(.subheadline)
                                    .foregroundColor(.neonMagenta)
                            }
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

                        // Pickleball fun fact
                        VStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.white.opacity(0.6))
                            Text("Pickleball is the fastest growing sport in America!")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
