# Copilot instructions for `pickleball-training-genie-ios`

## Build, run, test, and lint

- Xcode project: `PickleballTrainingGenie.xcodeproj`
- App scheme/target: `PickleballTrainingGenie`
- Deployment target: iOS 17+
- Build from the CLI:
  - `xcodebuild -project PickleballTrainingGenie.xcodeproj -scheme PickleballTrainingGenie -configuration Debug -destination 'generic/platform=iOS Simulator' build`
- Run in Xcode:
  - Open `PickleballTrainingGenie.xcodeproj`
  - Set `API_BASE_URL` in the Run scheme environment if you are not using the default backend at `http://localhost:5000/`
- There is currently no test target in the Xcode project, so there is no repository-defined full-suite or single-test command yet.
- There is currently no lint configuration in the repo (no SwiftLint or similar config checked in).

## High-level architecture

- This is a native SwiftUI iOS app with a lightweight MVVM split:
  - `PickleballTrainingGenieApp.swift` creates the single shared `AuthViewModel`
  - `ContentView.swift` (`RootView`) switches between auth flow and the main tab UI
  - `API/PickleballTrainingGenieClient.swift` contains both the HTTP client and the app's `Codable` API models
  - `ViewModels/` owns async loading state, user-facing error strings, and screen data
  - `Views/` stays mostly declarative and triggers work through `Task { ... }` and `.task`
- Authentication state is the root of the app:
  - `AuthViewModel` creates the shared `PickleballTrainingGenieClient`
  - On launch it restores the JWT from Keychain and marks the session authenticated before any login UI is shown
  - When authenticated, `RootView` creates `DrillsViewModel(client: authViewModel.client)` so authenticated drill, recommendation, and workout calls all reuse the same client and token
- The main user flow is tab-based:
  - `DrillsListView` browses/filter/searches drills
  - `RecommendationsView` loads authenticated personalized drill suggestions
  - `WorkoutView` generates an AI workout plan from the backend
  - `ProfileView` reads user state from `AuthViewModel`

## Key conventions

- Keep auth tokens in Keychain, not `UserDefaults`. The token key is `jwtToken`, managed through `Utilities/KeychainHelper.swift`.
- Reuse the shared `PickleballTrainingGenieClient` from `AuthViewModel` for app flows that depend on auth. Do not introduce parallel client instances for normal runtime state unless there is a clear isolation reason such as previews.
- API base URL comes from `ProcessInfo.processInfo.environment["API_BASE_URL"]` and defaults to `http://localhost:5000/`. Keep the protocol and trailing slash when setting it.
- View models are `@MainActor` and own loading/error state. Views are expected to call async methods and render published state, rather than performing URLSession work directly.
- The API client centralizes endpoint behavior behind `request(..., requireAuth:)`; authenticated endpoints rely on the `requireAuth` flag and `client.jwtToken` rather than setting headers ad hoc in views or view models.
- Prefer the shared theme primitives in `Theme/AppTheme.swift` over one-off styling:
  - brand colors via `Color.pickleballGreen` / `Color.pickleballYellow`
  - cards via `.pickleballCard()`
  - buttons via `PrimaryButtonStyle` and `SecondaryButtonStyle`
  - drill metadata via `DUPRBadge` and `CategoryBadge`
- The drill and recommendation screens load lazily on first appearance using `.task` only when their backing arrays are empty, and they expose manual refresh through toolbar buttons. Preserve that pattern when adding new fetches.
