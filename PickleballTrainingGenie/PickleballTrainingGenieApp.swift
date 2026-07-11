import SwiftUI
import GoogleSignIn

@main
struct PickleballTrainingGenieApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                if showSplash {
                    SynthwaveSplashView {
                        withAnimation { showSplash = false }
                    }
                } else {
                    RootView()
                        .environmentObject(authViewModel)
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
