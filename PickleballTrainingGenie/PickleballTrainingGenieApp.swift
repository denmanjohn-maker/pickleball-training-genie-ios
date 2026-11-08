import SwiftUI
import GoogleSignIn

@main
struct PickleballTrainingGenieApp: App {
    @StateObject private var authViewModel = AuthViewModel(restoreSession: {
        #if DEBUG
        return ProcessInfo.processInfo.environment["GENIE_UI_TEST"] != "1"
        #else
        return true
        #endif
    }())
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.environment["GENIE_UI_TEST"] == "1" {
                    UITestMainView()
                } else {
                    appContent
                }
                #else
                appContent
                #endif
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }

    private var appContent: some View {
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
    }
}
