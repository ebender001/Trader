import Foundation

enum TraderUIFormatting {
    static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD"))
    }

    static func signedCurrency(_ value: Double) -> String {
        let formattedValue = currency(abs(value))
        return value < 0 ? "-\(formattedValue)" : "+\(formattedValue)"
    }

    static func percent(_ value: Double) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(2)))
    }

    static func optionalPrice(_ value: String?) -> String {
        guard let value, let doubleValue = Double(value) else { return "Market" }
        return currency(doubleValue)
    }

    static func dateTime(_ value: String) -> String {
        if let date = date(from: value) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        return value
    }

    static func date(from value: String) -> Date? {
        isoDateFormatterWithFractionalSeconds.date(from: value) ??
            isoDateFormatter.date(from: value)
    }

    static func isoString(_ date: Date) -> String {
        isoDateFormatter.string(from: date)
    }

    private static let isoDateFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
