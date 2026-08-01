import Foundation

/// Public-facing URLs for the app. These are the same URLs registered as the
/// Privacy Policy and Support URLs in App Store Connect — keep them in sync.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://denmanjohn-maker.github.io/pickleball-training-genie-ios/privacy.html")!
    static let support = URL(string: "https://denmanjohn-maker.github.io/pickleball-training-genie-ios/support.html")!
}

/// Bundle-derived app version, so displayed values can't drift from the build.
enum AppInfo {
    static var marketingVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    static var versionString: String {
        "Version \(marketingVersion) (\(buildNumber))"
    }
}
