import Foundation

/// Seeds the backend database with a test account on debug builds.
/// Safe to call on every launch — a 400 response (account already exists) is silently ignored.
enum SeedHelper {
    private static let testEmail = "denman.john@gmail.com"
    private static let testPassword = "Blakd@l3k"
    private static let testDUPR: Decimal = 4.0

    /// Attempts to register the test account against the provided client.
    /// Errors are suppressed so seeding never interrupts normal app startup.
    static func seedTestAccount(using client: PickleballTrainingGenieClient) async {
        do {
            _ = try await client.register(
                email: testEmail,
                password: testPassword,
                currentDUPR: testDUPR,
                targetDUPR: testDUPR
            )
        } catch PickleballTrainingGenieError.invalidResponse(let code) where code == 400 {
            // Account already exists — this is expected on subsequent launches.
        } catch {
            // Non-fatal: log and continue.
            print("[SeedHelper] Could not seed test account: \(error)")
        }
    }
}
