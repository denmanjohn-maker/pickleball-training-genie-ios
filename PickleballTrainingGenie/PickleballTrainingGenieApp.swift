import SwiftUI

@main
struct PickleballTrainingGenieApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashVideoView {
                    withAnimation { showSplash = false }
                }
            } else {
                RootView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
