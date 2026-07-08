import Foundation

enum TournamentDateFormatting {
    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let displayFormatterNoYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    static func parse(_ raw: String) -> Date? {
        apiDateFormatter.date(from: raw)
    }

    /// e.g. "Aug 12, 2026" for a single date, or "Aug 12 – Aug 14, 2026" for a range.
    static func displayRange(startDate: String, endDate: String?) -> String {
        guard let start = parse(startDate) else { return startDate }
        guard let endRaw = endDate, let end = parse(endRaw), end != start else {
            return displayFormatter.string(from: start)
        }
        return "\(displayFormatterNoYear.string(from: start)) – \(displayFormatter.string(from: end))"
    }
}

enum TournamentCurrencyFormatting {
    /// Formats an entry fee using the tournament's currency code, e.g. "$25.00". Falls back to a
    /// plain decimal string with the raw currency code if it isn't a recognized ISO 4217 code.
    static func format(_ amount: Decimal, currency: String?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        if let formatted = formatter.string(from: amount as NSDecimalNumber) {
            return formatted
        }
        let plain = NSDecimalNumber(decimal: amount).stringValue
        return currency.map { "\(plain) \($0)" } ?? plain
    }
}
