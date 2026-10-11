import XCTest
@testable import PickleballTrainingGenie

final class JWTClaimsTests: XCTestCase {
    /// Builds an unsigned JWT with the given payload (signature isn't inspected).
    private func token(payload: String) -> String {
        func base64url(_ string: String) -> String {
            Data(string.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return base64url(#"{"alg":"HS256","typ":"JWT"}"#) + "." + base64url(payload) + ".sig"
    }

    func testReadsExpirationClaim() {
        let date = JWTClaims.expirationDate(of: token(payload: #"{"sub":"u1","exp":1900000000}"#))
        XCTAssertEqual(date, Date(timeIntervalSince1970: 1_900_000_000))
    }

    func testExpiredAndLiveTokens() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(JWTClaims.isExpired(token(payload: #"{"exp":999000}"#), now: now))
        XCTAssertFalse(JWTClaims.isExpired(token(payload: #"{"exp":1100000}"#), now: now))
    }

    func testLeewayTreatsNearlyExpiredAsExpired() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(JWTClaims.isExpired(token(payload: #"{"exp":1000010}"#), now: now, leeway: 30))
        XCTAssertFalse(JWTClaims.isExpired(token(payload: #"{"exp":1000010}"#), now: now, leeway: 0))
    }

    func testTokensWithoutReadableExpiryAreNotTreatedAsExpired() {
        XCTAssertNil(JWTClaims.expirationDate(of: "not-a-jwt"))
        XCTAssertNil(JWTClaims.expirationDate(of: token(payload: #"{"sub":"u1"}"#)))
        XCTAssertFalse(JWTClaims.isExpired("not-a-jwt"))
    }
}
