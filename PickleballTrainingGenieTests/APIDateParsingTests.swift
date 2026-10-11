import XCTest
@testable import PickleballTrainingGenie

final class APIDateParsingTests: XCTestCase {
    private let expected = Fixtures.date(2026, 8, 1, hour: 12).addingTimeInterval(34 * 60 + 56) // 12:34:56Z

    func testPlainISO8601() {
        XCTAssertEqual(APIDateParsing.parse("2026-08-01T12:34:56Z"), expected)
    }

    func testMillisecondFraction() {
        XCTAssertEqual(APIDateParsing.parse("2026-08-01T12:34:56.123Z")?.timeIntervalSince1970 ?? 0,
                       expected.timeIntervalSince1970 + 0.123, accuracy: 0.001)
    }

    func testMicrosecondFractionFromDotNet() {
        // ISO8601DateFormatter rejects 6-digit fractions; the parser strips them.
        XCTAssertEqual(APIDateParsing.parse("2026-08-01T12:34:56.440282Z"), expected)
    }

    func testMissingTimeZoneIsAssumedUTC() {
        XCTAssertEqual(APIDateParsing.parse("2026-08-01T12:34:56"), expected)
    }

    func testGarbageReturnsNilAndDisplaysRaw() {
        XCTAssertNil(APIDateParsing.parse("yesterday"))
        XCTAssertEqual(APIDateParsing.display("yesterday"), "yesterday")
    }
}
