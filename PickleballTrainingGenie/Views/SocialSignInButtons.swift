import SwiftUI
import AuthenticationServices

/// Reusable "or continue with" divider plus Continue-with-Apple and Continue-with-Google
/// buttons. Used by both `LoginView` and `RegisterView` — social sign-in doubles as account
/// creation (the first sign-in provisions the account), so the same block belongs on both.
/// The neutral "Continue with…" wording reads correctly on the login and create-account screens alike.
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

            SignInWithAppleButton(.continue) { request in
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
                // Typography mirrors SignInWithAppleButton above, which renders
                // its title at 19pt SF Medium for a 48pt-tall button — measured
                // from screenshots so the two buttons read as a pair.
                HStack(spacing: 8) {
                    GoogleGLogo()
                        .frame(width: 20, height: 20)
                    Text("Continue with Google")
                        .font(.system(size: 19, weight: .medium))
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

/// Google's four-color "G" mark, drawn from the official 48×48 logo geometry —
/// vector, so no bitmap asset is needed. Brand colors are fixed values (the
/// mark always sits on the white button, in any color scheme).
private struct GoogleGLogo: View {
    private static let blue   = Color(red: 0.259, green: 0.522, blue: 0.957) // #4285F4
    private static let green  = Color(red: 0.204, green: 0.659, blue: 0.325) // #34A853
    private static let yellow = Color(red: 0.984, green: 0.737, blue: 0.020) // #FBBC05
    private static let red    = Color(red: 0.918, green: 0.263, blue: 0.208) // #EA4335

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 48
            context.scaleBy(x: scale, y: scale)
            context.fill(Self.bluePath, with: .color(Self.blue))
            context.fill(Self.greenPath, with: .color(Self.green))
            context.fill(Self.yellowPath, with: .color(Self.yellow))
            context.fill(Self.redPath, with: .color(Self.red))
        }
        .accessibilityHidden(true)
    }

    /// Right side: the horizontal bar and outer arc down to the bottom-right notch.
    private static let bluePath = Path { p in
        p.move(to: CGPoint(x: 46.98, y: 24.55))
        p.addCurve(to: CGPoint(x: 46.60, y: 20.00),
                   control1: CGPoint(x: 46.98, y: 22.98),
                   control2: CGPoint(x: 46.83, y: 21.46))
        p.addLine(to: CGPoint(x: 24.00, y: 20.00))
        p.addLine(to: CGPoint(x: 24.00, y: 29.02))
        p.addLine(to: CGPoint(x: 36.94, y: 29.02))
        p.addCurve(to: CGPoint(x: 32.16, y: 36.20),
                   control1: CGPoint(x: 36.36, y: 31.98),
                   control2: CGPoint(x: 34.68, y: 34.50))
        p.addLine(to: CGPoint(x: 39.89, y: 42.20))
        p.addCurve(to: CGPoint(x: 46.98, y: 24.55),
                   control1: CGPoint(x: 44.40, y: 38.02),
                   control2: CGPoint(x: 46.98, y: 31.84))
        p.closeSubpath()
    }

    /// Bottom arc.
    private static let greenPath = Path { p in
        p.move(to: CGPoint(x: 24.00, y: 48.00))
        p.addCurve(to: CGPoint(x: 39.89, y: 42.19),
                   control1: CGPoint(x: 30.48, y: 48.00),
                   control2: CGPoint(x: 35.93, y: 45.87))
        p.addLine(to: CGPoint(x: 32.16, y: 36.19))
        p.addCurve(to: CGPoint(x: 24.00, y: 38.49),
                   control1: CGPoint(x: 30.01, y: 37.64),
                   control2: CGPoint(x: 27.24, y: 38.49))
        p.addCurve(to: CGPoint(x: 10.53, y: 28.58),
                   control1: CGPoint(x: 17.74, y: 38.49),
                   control2: CGPoint(x: 12.43, y: 34.27))
        p.addLine(to: CGPoint(x: 2.55, y: 34.77))
        p.addCurve(to: CGPoint(x: 24.00, y: 48.00),
                   control1: CGPoint(x: 6.51, y: 42.62),
                   control2: CGPoint(x: 14.62, y: 48.00))
        p.closeSubpath()
    }

    /// Left arc.
    private static let yellowPath = Path { p in
        p.move(to: CGPoint(x: 10.53, y: 28.59))
        p.addCurve(to: CGPoint(x: 9.77, y: 24.00),
                   control1: CGPoint(x: 10.05, y: 27.14),
                   control2: CGPoint(x: 9.77, y: 25.60))
        p.addCurve(to: CGPoint(x: 10.53, y: 19.41),
                   control1: CGPoint(x: 9.77, y: 22.40),
                   control2: CGPoint(x: 10.04, y: 20.86))
        p.addLine(to: CGPoint(x: 2.55, y: 13.22))
        p.addCurve(to: CGPoint(x: 0.00, y: 24.00),
                   control1: CGPoint(x: 0.92, y: 16.46),
                   control2: CGPoint(x: 0.00, y: 20.12))
        p.addCurve(to: CGPoint(x: 2.56, y: 34.78),
                   control1: CGPoint(x: 0.00, y: 27.88),
                   control2: CGPoint(x: 0.92, y: 31.54))
        p.closeSubpath()
    }

    /// Top arc.
    private static let redPath = Path { p in
        p.move(to: CGPoint(x: 24.00, y: 9.50))
        p.addCurve(to: CGPoint(x: 33.21, y: 13.10),
                   control1: CGPoint(x: 27.54, y: 9.50),
                   control2: CGPoint(x: 30.71, y: 10.72))
        p.addLine(to: CGPoint(x: 40.06, y: 6.25))
        p.addCurve(to: CGPoint(x: 24.00, y: 0.00),
                   control1: CGPoint(x: 35.90, y: 2.38),
                   control2: CGPoint(x: 30.47, y: 0.00))
        p.addCurve(to: CGPoint(x: 2.56, y: 13.22),
                   control1: CGPoint(x: 14.62, y: 0.00),
                   control2: CGPoint(x: 6.51, y: 5.38))
        p.addLine(to: CGPoint(x: 10.54, y: 19.41))
        p.addCurve(to: CGPoint(x: 24.00, y: 9.50),
                   control1: CGPoint(x: 12.43, y: 13.72),
                   control2: CGPoint(x: 17.74, y: 9.50))
        p.closeSubpath()
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
