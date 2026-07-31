import SwiftUI
import AuthenticationServices

/// Reusable "or continue with" divider plus Sign in with Apple and Google buttons.
/// Used by both `LoginView` and `RegisterView` — social sign-in doubles as account
/// creation (the first sign-in provisions the account), so the same block belongs on both.
struct SocialSignInButtons: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Divider
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
        }
    }
}

#Preview {
    ZStack {
        SynthwaveGradient()
        SocialSignInButtons()
            .environmentObject(AuthViewModel())
            .padding()
    }
}
