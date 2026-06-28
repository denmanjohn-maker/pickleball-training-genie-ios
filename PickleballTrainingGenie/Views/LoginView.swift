import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            ZStack {
                PickleballGradient()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            Image("Logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 120)
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)

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

                            Button {
                                showRegister = true
                            } label: {
                                Text("New to Pickleball Genie? **Create Account**")
                                    .font(.subheadline)
                                    .foregroundColor(.neonVolt)
                            }
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(20)
                        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
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
