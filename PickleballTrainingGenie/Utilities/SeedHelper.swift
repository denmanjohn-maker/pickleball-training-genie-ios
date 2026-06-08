import Foundation

/// Seeds the backend database with a test account on debug builds.
/// Credentials can be overridden via environment variables; the defaults are used as fallbacks.
/// Safe to call on every launch — a 400 response (account already exists) is silently ignored.
enum SeedHelper {
    private enum Config {
        static let email = ProcessInfo.processInfo.environment["SEED_TEST_EMAIL"]
            ?? "denman.john@gmail.com"
        static let password = ProcessInfo.processInfo.environment["SEED_TEST_PASSWORD"]
            ?? "Blakd@l3k"
        static let dupr: Decimal = {
            if let raw = ProcessInfo.processInfo.environment["SEED_TEST_DUPR"],
               let value = Decimal(string: raw) {
                return value
            }
            return 4.0
        }()
    }

    /// Attempts to register the test account against the provided client.
    /// Errors are suppressed so seeding never interrupts normal app startup.
    static func seedTestAccount(using client: PickleballTrainingGenieClient) async {
        do {
            _ = try await client.register(
                email: Config.email,
                password: Config.password,
                currentDUPR: Config.dupr,
                targetDUPR: Config.dupr
            )
        } catch PickleballTrainingGenieError.invalidResponse(let code) where code == 400 {
            // Account already exists — this is expected on subsequent launches.
        } catch {
            // Non-fatal: log and continue.
            print("[SeedHelper] Could not seed test account: \(error)")
        }
    }
}

