import Foundation
import OSLog

/// Structured logging via the unified logging system. Use these instead of
/// `print`: messages land in Console.app and sysdiagnose with a subsystem and
/// category you can filter on, and `.debug` lines cost nothing in release.
///
/// Mark anything that could be personal (emails, names, tokens) `.private` —
/// the default — and only pass `privacy: .public` for codes and paths.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.jdtechprojects.pickleballgenie"

    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let session = Logger(subsystem: subsystem, category: "guided-session")
    static let cache = Logger(subsystem: subsystem, category: "cache")
}
