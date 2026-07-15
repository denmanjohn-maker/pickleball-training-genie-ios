# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Native iOS client (SwiftUI, Swift 5.10, async/await) for **Pickleball Genie**, an AI-powered training coach. It talks to a separate backend REST API (not in this repo) for auth, drills/recommendations, AI-generated workouts, and tournaments.

## Build & run

- Open `PickleballTrainingGenie.xcodeproj` in Xcode 15+, targeting iOS 17+.
- There are no test targets, and no CLI lint/build scripts — build and run via Xcode (Cmd+R) or `xcodebuild` against the `PickleballTrainingGenie` scheme.
- The app defaults to the hosted API at `https://thepickleballgenie.com/`. To point at a local backend, set environment variables on the Run scheme (Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables):
  - `API_BASE_URL` — main backend (auth, drills, workouts, profile). E.g. `http://localhost:5123/` (dotnet run) or `http://localhost:8080/` (Docker Compose).
  - `TOURNAMENTS_API_BASE_URL` — tournaments backend, read separately by `TournamentsAPIClient`.
  - Both must include protocol and trailing slash. On a physical device, use the Mac's LAN IP instead of `localhost`.
- `scripts/generate_zip_centroids.py` regenerates `PickleballTrainingGenie/Resources/ZipPrefixCentroids.json`, used by `ZipCityMatcher` to map ZIP codes to home cities during onboarding.

## Architecture

MVVM with a thin API-client layer. Two independent backend clients exist side by side (main app API and tournaments API) — do not conflate them when adding features.

- **Entry point**: `PickleballTrainingGenieApp.swift` shows a splash (`SynthwaveSplashView`), then renders `RootView` (`ContentView.swift`) which owns the single top-level `AuthViewModel` via `@StateObject`/`@EnvironmentObject`.
- **Root routing** (`ContentView.swift`): `RootView` is the sole gate deciding what's on screen based on `AuthViewModel` state:
  - not authenticated → `LoginView`
  - authenticated, profile incomplete (`User.needsOnboarding`) → `OnboardingFlowView`
  - authenticated, profile loaded → `MainTabView`, which is handed fresh `DrillsViewModel` and `TournamentsViewModel` instances as environment objects (constructed here, not injected higher up)
  - profile fetch failed → a retry screen
- **Auth** (`ViewModels/AuthViewModel.swift`): owns the single `PickleballTrainingGenieClient` instance for the whole app, restores session from the Keychain on launch, drives login/register/logout and profile fetch/update. Other view models receive `client` from `AuthViewModel` rather than constructing their own.
- **API clients** (`API/`):
  - `PickleballTrainingGenieClient.swift` — main REST client (auth, profile, drills, recommendations, AI workout generation, workout history) plus all `Codable` request/response models for that domain, all in one file.
  - `TournamentsAPIClient.swift` / `TournamentsModels.swift` — separate client/models for the tournaments feature, with its own base URL config (`TournamentsAPIConfig`, from `TOURNAMENTS_API_BASE_URL`).
  - Both clients inject bearer auth headers and read their base URL from `ProcessInfo.processInfo.environment`, falling back to the hosted production URL.
- **ViewModels** (`ViewModels/`): one `@MainActor` `ObservableObject` per feature area (`DrillsViewModel`, `OnboardingViewModel`, `TournamentsViewModel`, `WorkoutHistoryViewModel`), each wrapping its client and exposing published UI state/errors. `OnboardingViewModel` also holds a `TournamentsAPIClient` to look up home city during signup.
- **Views** (`Views/`) are grouped by feature (auth, onboarding, drills, tournaments, workout history, profile) and consume the environment-injected view models — they don't talk to API clients directly.
- **Theme** (`Theme/AppTheme.swift`, `AvatarView.swift`): shared "synthwave" visual system — brand colors as `Color` extensions, custom button styles, badges. Reuse these instead of ad hoc styling in new views.
- **Utilities**: `KeychainHelper` (JWT token storage), `ZipCityMatcher` + `ZipPrefixCentroids.json` (ZIP → nearest city lookup for onboarding), `DateFormatting`, `ImageResizing` (avatar uploads).

## Conventions

- `User` models are decoded with several optional fields explicitly kept optional to stay compatible with backends that predate newer profile fields (see comments in `PickleballTrainingGenieClient.swift`) — don't force-unwrap these or make them non-optional without checking backend compatibility.
- Request payloads that send DUPR ratings use `Double`, not `Decimal`, so `JSONEncoder` emits clean values (e.g. `3.5` instead of a `Decimal` representation).
- Network-reachability errors surface a user-facing hint that mentions the relevant `*_API_BASE_URL` env var and localhost caveat for physical devices (see `AuthViewModel.swift`/`TournamentsViewModel.swift`) — follow this pattern for new clients.
