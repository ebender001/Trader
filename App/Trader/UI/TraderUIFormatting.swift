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
}
