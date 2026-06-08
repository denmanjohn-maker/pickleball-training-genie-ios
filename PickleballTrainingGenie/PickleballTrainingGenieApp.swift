import SwiftUI

@main
struct PickleballTrainingGenieApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                #if DEBUG
                .task {
                    await SeedHelper.seedTestAccount(using: authViewModel.client)
                }
                #endif
        }
    }
}
