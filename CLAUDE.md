# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Native iOS client (SwiftUI, Swift 5.10, async/await, iOS 17+) for **Pickleball Genie**, an AI-powered training coach aimed at players who can't get to a human coach. It talks to a separate backend REST API (not in this repo) for auth, drills/recommendations, AI-generated workouts, workout history, and tournaments. A large part of the app now works offline: bundled Learn content, cached drills/workouts, guided sessions, streaks, and on-device video self-review.

## Build, test, lint

- Open `PickleballTrainingGenie.xcodeproj` in Xcode 15+ (CI uses Xcode 16 on `macos-15`).
- **Unit tests** live in the `PickleballTrainingGenieTests` target (XCTest, hosted by the app). Run with Cmd+U or:
  ```sh
  xcodebuild test -project PickleballTrainingGenie.xcodeproj -scheme PickleballTrainingGenie \
    -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
  ```
  Tests cover pure logic only (API client via a stub `URLProtocol`, parsers, stats, assessment scoring, view-model filtering, guided-session timing). Keep new logic in testable, UI-free types and add a test alongside it.
- **Lint**: `swiftlint` from the repo root (`.swiftlint.yml`). CI runs it; warnings don't fail the build, errors do.
- **CI**: `.github/workflows/ios.yml` lints, builds, and runs the tests on every PR and on pushes to `main`.
- `Package.resolved` (under `PickleballTrainingGenie.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`) is meant to be committed; Xcode writes it on first package resolution. Commit it when it appears so dependency versions are pinned.
- The app defaults to the hosted API at `https://thepickleballgenie.com/`. To point at a local backend, set environment variables on the Run scheme (Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables):
  - `API_BASE_URL` — main backend. E.g. `http://localhost:5123/` (dotnet run) or `http://localhost:8080/` (Docker Compose).
  - `TOURNAMENTS_API_BASE_URL` — tournaments backend, read separately by `TournamentsAPIClient`.
  - Both must include protocol and trailing slash. On a physical device, use the Mac's LAN IP instead of `localhost`.
- `scripts/generate_zip_centroids.py` regenerates `Resources/ZipPrefixCentroids.json`, used by `ZipCityMatcher`.

## Architecture

MVVM with a thin API-client layer. Two independent backend clients exist side by side (main app API and tournaments API) — do not conflate them.

- **Entry point**: `PickleballTrainingGenieApp.swift` shows `SynthwaveSplashView`, then `RootView` (`ContentView.swift`), which owns the single `AuthViewModel`.
- **Root routing** (`ContentView.swift`): `RootView` decides what's on screen from `AuthViewModel` state: not authenticated → `LoginView`; profile incomplete (`User.needsOnboarding`) → `OnboardingFlowView`; first run → `AppTutorialView`; otherwise `MainTabView` (tab bar on iPhone, sidebar on iPad) with fresh `DrillsViewModel` and `TournamentsViewModel` as environment objects; profile fetch failed → retry screen.
- **Auth** (`ViewModels/AuthViewModel.swift`): owns the one `PickleballTrainingGenieClient`, restores the JWT from Keychain (skipping tokens whose `exp` has passed), drives email/Google/Apple sign-in, profile fetch/update, and account deletion (`LocalDataPurge` wipes on-device data). It sets `client.onUnauthorized` so any 401 on an authenticated call signs the user out once, centrally.
- **API clients** (`API/`):
  - `PickleballTrainingGenieClient.swift` — main REST client plus all `Codable` models for that domain. One `perform`/`send` path adds the bearer header, applies timeouts (30s request, 90s for AI workout generation), decodes server error bodies (`ServerErrorBody`: ASP.NET ProblemDetails, `{message}`, plain text) into `PickleballTrainingGenieError.invalidResponse(statusCode:serverMessage:)`, and fires `onUnauthorized`. The error conforms to `LocalizedError`, so `error.localizedDescription` shows the server's message. `JWTClaims` reads `exp` without verifying.
  - `TournamentsAPIClient.swift` / `TournamentsModels.swift` — separate client/models with its own base URL (`TournamentsAPIConfig`).
- **ViewModels** (`ViewModels/`): one `@MainActor` `ObservableObject` per feature (`DrillsViewModel`, `OnboardingViewModel`, `TournamentsViewModel`, `WorkoutHistoryViewModel`, `TrainingStreakStore`, `GuidedSessionViewModel`). `DrillsViewModel` and `TrainingStreakStore` fall back to `OfflineCache` when the network fails and expose the cache date for banners. `GuidedSessionViewModel` runs a workout as a timed session: wall-clock based countdown, pause/skip/+1 min, haptic + spoken cues through an `AVAudioSession` playback category, and a local notification at drill end when the app is backgrounded. Its `now` closure and `integratesWithSystem` flag exist for tests.
- **Models** (`Models/`): `SkillLevel` (single source of truth for the 2.0–5.0 scale), `SkillAssessment` (60-second skill check, stored locally, used to re-rank recommendations), `TrainingStats` (streak/weekly-goal math), `DrillSoloHeuristic` (keyword guess at partner-free drills until the backend tags them).
- **Views** (`Views/`) by feature: auth, onboarding, drills + Learn, recommendations, workout + guided session, tournaments, history, profile (habits card, reminders, video review). Views consume environment view models and never call API clients directly.
- **Theme** (`Theme/AppTheme.swift`, `AvatarView.swift`): synthwave visual system — brand colors, `surfaceMuted`/`fieldBackground` tokens, button styles, badges, `readableWidth()`. Reuse these; don't reach for `Color(.systemGray…)` or fixed point sizes (use text styles or `@ScaledMetric`).
- **Utilities**: `KeychainHelper` (JWT), `OfflineCache` (Codable JSON in Application Support), `TrainingReminders` (local notifications), `FavoriteDrills`, `VideoReviewStore` (clips in Documents, excluded from backup), `LocalDataPurge`, `ZipCityMatcher`, `AppLog` (`os.Logger` categories — use instead of `print`).

## Conventions

- `User` keeps several fields optional for compatibility with older backends (see comments in the client) — don't force-unwrap or make them non-optional without checking the backend.
- Request payloads that send DUPR ratings use `Double`, not `Decimal`, so `JSONEncoder` emits clean values.
- Match `PickleballTrainingGenieError` as `.invalidResponse(let code, _)`; when showing a generic failure, prefer `error.serverMessage ?? "fallback"` so backend validation text reaches the user.
- Network-reachability errors surface a hint naming the relevant `*_API_BASE_URL` env var and the localhost caveat for physical devices (see `AuthViewModel`/`TournamentsViewModel`) — follow this for new clients.
- Any new on-device storage must be added to `LocalDataPurge` so account deletion erases it.
- Personalized caches are keyed per user id; the public drill library is cached globally.
