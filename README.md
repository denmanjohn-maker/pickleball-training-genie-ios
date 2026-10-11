# Pickleball Training Genie iOS Client

An elegant, modern iOS client application for **Pickleball Genie**, your AI-powered training coach. Built natively using Swift and SwiftUI, this application helps pickleball players of all levels elevate their games by browsing skill drills, receiving personalized recommendations based on their DUPR ratings, and generating custom AI training workouts.

---

## 🚀 Key Technologies Used

- **SwiftUI**: Modern, declarative UI framework with responsive layouts and state-driven animations.
- **Swift 5.10 & Concurrency (Async/Await)**: Leverages modern Swift concurrency for non-blocking network calls, clean asynchronous routines, and `@MainActor` thread-safety annotations on view models.
- **Keychain Services (Security API)**: Secure storage of JWT authentication tokens on the device's keychain using custom `KeychainHelper` APIs. Expired tokens are detected on launch, and any 401 on an authenticated call signs the user out centrally.
- **Offline-first training**: drills, recommendations and the current workout are cached on disk; Learn content is bundled; guided sessions run from a wall clock with spoken cues and a local notification when the phone is pocketed.
- **MVVM Architecture**: Clear separation of concerns with Models (Core structs), Views (SwiftUI structures), ViewModels (ObservableObjects driving UI state), and Services (API client layer).
- **ProcessInfo Environments**: Supports dynamic backend server targets through customizable environment variables.

---

## 📂 Project Organization & Codebase Structure

```text
PickleballTrainingGenie/
├── PickleballTrainingGenieApp.swift    # App entry point (splash → RootView)
├── ContentView.swift                   # RootView routing + MainTabView (tab bar / iPad sidebar)
├── API/
│   ├── PickleballTrainingGenieClient.swift  # Main REST client, Codable models, error + JWT helpers
│   ├── TournamentsAPIClient.swift           # Separate tournaments client
│   └── TournamentsModels.swift
├── Models/                             # SkillLevel scale, skill assessment, training stats, solo heuristic
├── ViewModels/                         # Auth, Drills, Onboarding, Tournaments, History, Streaks, Guided Session
├── Views/                              # Auth, onboarding, drills + Learn, workout + guided session,
│                                       # tournaments, history, profile, video self-review, tutorial
├── Theme/                              # Synthwave palette, button styles, badges, avatar
├── Utilities/                          # Keychain, OfflineCache, reminders, favorites, video store,
│                                       # LocalDataPurge, ZipCityMatcher, AppLog
└── Resources/                          # LearnContent.json, ZipPrefixCentroids.json
PickleballTrainingGenieTests/           # XCTest unit tests (hosted by the app)
.github/workflows/ios.yml               # CI: SwiftLint + build + tests on iOS Simulator
```

---

## 🧪 Tests, lint, and CI

- **Unit tests** (`PickleballTrainingGenieTests`) run with Cmd+U in Xcode, or from the terminal:

  ```sh
  xcodebuild test -project PickleballTrainingGenie.xcodeproj -scheme PickleballTrainingGenie \
    -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
  ```

  They cover the API client (through a stub `URLProtocol`, no network), server error parsing, JWT expiry, date parsing, streak math, skill-assessment scoring and ranking, drill level fallback, guided-session timing, the offline cache, and the solo-drill heuristic.
- **Lint**: `brew install swiftlint && swiftlint` from the repo root. Configuration is in `.swiftlint.yml`.
- **CI**: GitHub Actions (`.github/workflows/ios.yml`) lints, builds, and runs the tests on every pull request and on pushes to `main`.
- **Dependency pinning**: `Package.resolved` is no longer gitignored and is meant to be committed. It isn't in the repository yet — Xcode writes it under `PickleballTrainingGenie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/` on first package resolution; commit it when it appears so every build resolves the same dependency versions.

---

## ⚙️ Setup & Configuration

### Prerequisites
- **Xcode 15.0+**
- **iOS 17.0+** or compatible simulator

### Running the App
1. Open `PickleballTrainingGenie.xcodeproj` in Xcode.
2. By default, the client connects to the hosted API at `https://thepickleballgenie.com/`.
3. To use a different backend for development, define `API_BASE_URL` in your Xcode scheme's Environment Variables (under **Run** -> **Arguments**). For local API work, use `http://localhost:5123/` for `dotnet run` or `http://localhost:8080/` for Docker Compose. The URL must include the protocol and trailing slash (for example `API_BASE_URL=http://localhost:5123/` or `API_BASE_URL=https://api.example.com/`). On a physical iPhone or iPad, do not use `localhost`; use your Mac's LAN IP instead.
4. Select your target simulator or device, and click **Run** (Cmd + R).

### App Store submission

App Review asks for a screen recording of the app's core flows on a physical device. The recording recipe, shot list, and paste-ready review notes live in [`app-store/REVIEW_SCREEN_RECORDING.md`](app-store/REVIEW_SCREEN_RECORDING.md) and [`app-store/APP_REVIEW_NOTES.md`](app-store/APP_REVIEW_NOTES.md).
