import XCTest
@testable import PickleballTrainingGenie

final class APIClientTests: XCTestCase {
    private var client: PickleballTrainingGenieClient!

    override func setUp() {
        super.setUp()
        client = PickleballTrainingGenieClient(baseURL: Fixtures.baseURL, session: StubURLProtocol.makeSession())
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testDecodesSuccessfulResponse() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/Drills")
            let body = """
            [{"id":"d1","title":"Dink Rally","description":"Dink.","targetDUPRLevel":3.0,
              "category":"Dinking","videoUrl":null,"sourceUrl":"https://x","createdAt":"2026-01-01T00:00:00Z"}]
            """
            return (StubURLProtocol.response(for: request, status: 200), Data(body.utf8))
        }
        let drills = try await client.drills()
        XCTAssertEqual(drills.count, 1)
        XCTAssertEqual(drills.first?.title, "Dink Rally")
        XCTAssertEqual(drills.first?.targetDUPRLevel, 3.0)
    }

    func testValidationProblemDetailsBecomesServerMessage() async {
        StubURLProtocol.handler = { request in
            let body = """
            {"type":"https://tools.ietf.org/html/rfc7231#section-6.5.1",
             "title":"One or more validation errors occurred.","status":400,
             "errors":{"Email":["Email is already in use."]}}
            """
            return (StubURLProtocol.response(for: request, status: 400), Data(body.utf8))
        }
        do {
            _ = try await client.register(email: "a@b.c", password: "pw", singlesDUPR: nil, doublesDUPR: nil, targetDUPR: 3.5)
            XCTFail("Expected a 400 to throw")
        } catch let error as PickleballTrainingGenieError {
            XCTAssertEqual(error.statusCode, 400)
            XCTAssertEqual(error.serverMessage, "Email is already in use.")
            XCTAssertEqual(error.localizedDescription, "Email is already in use.")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testBearerTokenIsSentOnlyForAuthenticatedCalls() async throws {
        client.jwtToken = "abc"
        var seenAuthHeaders: [String?] = []
        StubURLProtocol.handler = { request in
            seenAuthHeaders.append(request.value(forHTTPHeaderField: "Authorization"))
            let body = request.url!.path.contains("profile")
                ? #"{"id":"u1","email":"a@b.c","isDuprLinked":false,"targetDUPR":3.5}"#
                : "[]"
            return (StubURLProtocol.response(for: request, status: 200), Data(body.utf8))
        }
        _ = try await client.getProfile()
        _ = try await client.drills()
        XCTAssertEqual(seenAuthHeaders, ["Bearer abc", nil])
    }

    func testUnauthorizedCallbackFiresForAuthenticatedRequest() async {
        client.jwtToken = "expired"
        let fired = expectation(description: "onUnauthorized")
        client.onUnauthorized = { fired.fulfill() }
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 401), Data())
        }
        _ = try? await client.getProfile()
        await fulfillment(of: [fired], timeout: 2)
    }

    func testStale401DoesNotSignOutAFreshSession() async {
        client.jwtToken = "old"
        client.onUnauthorized = { XCTFail("A 401 for a superseded token must not sign out the new session") }
        let client: PickleballTrainingGenieClient = self.client
        StubURLProtocol.handler = { request in
            // The user signed in again while this request was still in flight.
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer old" {
                client.jwtToken = "new"
            }
            return (StubURLProtocol.response(for: request, status: 401), Data())
        }
        _ = try? await client.getProfile()
        XCTAssertEqual(client.jwtToken, "new")
    }

    func testUnauthorizedCallbackDoesNotFireForLogin() async {
        client.onUnauthorized = { XCTFail("Wrong credentials are not an expired session") }
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 401), Data())
        }
        do {
            _ = try await client.login(email: "a@b.c", password: "nope")
            XCTFail("Expected 401 to throw")
        } catch let error as PickleballTrainingGenieError {
            XCTAssertEqual(error.statusCode, 401)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMissingAvatarIsNilNotError() async throws {
        client.jwtToken = "abc"
        StubURLProtocol.handler = { request in
            (StubURLProtocol.response(for: request, status: 404), Data())
        }
        let data = try await client.fetchAvatarData()
        XCTAssertNil(data)
    }

    func testDeleteAccountAcceptsEmptyBody() async throws {
        client.jwtToken = "abc"
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            return (StubURLProtocol.response(for: request, status: 204, headers: [:]), Data())
        }
        try await client.deleteAccount()
    }

    func testGenerateWorkoutUsesLongerTimeout() async throws {
        client.jwtToken = "abc"
        var timeout: TimeInterval = 0
        StubURLProtocol.handler = { request in
            timeout = request.timeoutInterval
            return (StubURLProtocol.response(for: request, status: 200), Data(#"{"drills":[]}"#.utf8))
        }
        _ = try await client.generateWorkout(durationMinutes: 30)
        XCTAssertEqual(timeout, 90)
    }
}
