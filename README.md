# Pickleball Training Genie iOS Client

An elegant, modern iOS client application for **Pickleball Genie**, your AI-powered training coach. Built natively using Swift and SwiftUI, this application helps pickleball players of all levels elevate their games by browsing skill drills, receiving personalized recommendations based on their DUPR ratings, and generating custom AI training workouts.

---

## 🚀 Key Technologies Used

- **SwiftUI**: Modern, declarative UI framework with responsive layouts and state-driven animations.
- **Swift 5.10 & Concurrency (Async/Await)**: Leverages modern Swift concurrency for non-blocking network calls, clean asynchronous routines, and `@MainActor` thread-safety annotations on view models.
- **Keychain Services (Security API)**: Secure storage of JWT authentication tokens on the device's keychain using custom `KeychainHelper` APIs.
- **MVVM Architecture**: Clear separation of concerns with Models (Core structs), Views (SwiftUI structures), ViewModels (ObservableObjects driving UI state), and Services (API client layer).
- **ProcessInfo Environments**: Supports dynamic backend server targets through customizable environment variables.

---

## 📂 Project Organization & Codebase Structure

The project code resides in the `PickleballTrainingGenie` folder and is organized cleanly into functional layers:

```text
PickleballTrainingGenie/
├── PickleballTrainingGenieApp.swift    # App entry point initializing AuthViewModel
├── ContentView.swift                   # Root view router switching Login & Tab views
├── API/
│   └── PickleballTrainingGenieClient.swift # Core HTTP REST API Client & JSON Models
├── ViewModels/
│   ├── AuthViewModel.swift             # Manages auth status, login, registration, & logout
│   └── DrillsViewModel.swift           # Handles drills fetching, filtering, & AI workouts
├── Views/
│   ├── LoginView.swift                 # Sign-in UI with validation & animations
│   ├── RegisterView.swift              # Account creation with current/target DUPR settings
│   ├── DrillsListView.swift            # Browsable skill drills repository with filters
│   ├── RecommendationsView.swift       # Personalized drills tailored to DUPR levels
│   ├── WorkoutView.swift               # AI generator producing custom drills sequences
│   ├── ProfileView.swift               # Player settings, DUPR level details, & sign-out
│   └── DrillDetailView.swift           # Deep-dive instructions, source, & video links
├── Theme/
│   └── AppTheme.swift                  # Reusable branding, button styles, & custom badges
└── Utilities/
    └── KeychainHelper.swift            # Low-level Swift wrappers for iOS Keychain API
```

---

## 🏛️ Core Component Breakdown

### 1. API Services (`API/`)
- **`PickleballTrainingGenieClient`**: Executes asynchronous requests (`GET`, `POST`) to the backend API, automatically injecting the required Authorization headers where necessary. Contains strongly typed `Codable` models representing users, drills, and AI workouts.

### 2. ViewModels (`ViewModels/`)
- **`AuthViewModel`**: Controls the authentication lifecycle. Automatically reads the keychain on launch to restore a previous session, and coordinates login and registration flows.
- **`DrillsViewModel`**: Governs data fetching for training drills, interactive filter state (Category, DUPR level), drill completions, and AI workout plan configurations.

### 3. Theme & Styling (`Theme/`)
- **`Color` Extensions**: Defines brand colors (`pickleballGreen`, `pickleballYellow`, `pickleballDarkGreen`, `pickleballLightGreen`).
- **Styles & Badges**: Implements custom button styles (`PrimaryButtonStyle`, `SecondaryButtonStyle`) and metadata badges (`DUPRBadge`, `CategoryBadge`) to establish a premium and consistent visual identity.

### 4. Utilities & Security (`Utilities/`)
- **`KeychainHelper`**: Bypasses insecure standard storage (like `UserDefaults`) by wrapping the `Security` framework's `SecItem` operations, ensuring authentication state remains private and secure.

---

## ⚙️ Setup & Configuration

### Prerequisites
- **Xcode 15.0+**
- **iOS 17.0+** or compatible simulator

### Running the App
1. Open `PickleballTrainingGenie.xcodeproj` in Xcode.
2. Ensure you have the Backend API server running. By default, the client looks for a local server at `http://localhost:5000/`.
3. To point the client to a different server environment (e.g., staging or production), define the `API_BASE_URL` environment variable in your Xcode scheme's Environment Variables (under **Run** -> **Arguments**). Note that the URL must include the protocol (e.g., `API_BASE_URL=https://api.example.com/` or `http://192.168.1.100:5000/`).
4. Select your target simulator or device, and click **Run** (Cmd + R).
