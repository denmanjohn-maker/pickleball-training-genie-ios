import SwiftUI

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
                        VStack(spacing: 10) {
                            GenieWordmark(scale: 0.55)

                            Image("Genie")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 56)
                        }
                        .padding(.top, 16)

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

                            // Social sign-in (Apple + Google)
                            SocialSignInButtons()

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
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
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
