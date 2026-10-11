import XCTest
@testable import PickleballTrainingGenie

final class ServerErrorBodyTests: XCTestCase {
    private func message(_ body: String) -> String? {
        ServerErrorBody.message(from: Data(body.utf8))
    }

    func testFieldErrorsAreJoinedInFieldOrder() {
        let body = #"{"title":"One or more validation errors occurred.","errors":{"Password":["Too short."],"Email":["Invalid email."]}}"#
        XCTAssertEqual(message(body), "Invalid email. Too short.")
    }

    func testDetailBeatsTitle() {
        XCTAssertEqual(message(#"{"title":"Bad Request","detail":"Rating must be between 2.0 and 8.0."}"#),
                       "Rating must be between 2.0 and 8.0.")
    }

    func testMessageFieldIsUsed() {
        XCTAssertEqual(message(#"{"message":"Email already registered"}"#), "Email already registered")
    }

    func testTitleIsLastResort() {
        XCTAssertEqual(message(#"{"title":"Conflict"}"#), "Conflict")
    }

    func testBareJSONString() {
        XCTAssertEqual(message(#""Account locked""#), "Account locked")
    }

    func testPlainText() {
        XCTAssertEqual(message("  Service unavailable \n"), "Service unavailable")
    }

    func testHTMLAndEmptyBodiesAreIgnored() {
        XCTAssertNil(message("<html><body>502 Bad Gateway</body></html>"))
        XCTAssertNil(message(""))
        XCTAssertNil(message("   "))
    }

    func testWhitespaceOnlyFieldsFallThrough() {
        XCTAssertEqual(message(#"{"detail":"  ","message":"Real message"}"#), "Real message")
    }

    func testLocalizedDescriptionPrefersServerMessageThenStatusText() {
        XCTAssertEqual(PickleballTrainingGenieError.invalidResponse(statusCode: 400, serverMessage: "Nope").localizedDescription, "Nope")
        XCTAssertEqual(PickleballTrainingGenieError.invalidResponse(statusCode: 401).localizedDescription,
                       "Your session has expired. Please sign in again.")
        XCTAssertEqual(PickleballTrainingGenieError.invalidResponse(statusCode: 0).localizedDescription,
                       "The server did not respond.")
        XCTAssertEqual(PickleballTrainingGenieError.invalidURL.localizedDescription, "Invalid server configuration.")
    }
}
