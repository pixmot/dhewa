import Foundation
import os

public enum MoneyParseError: Error, Equatable {
    case empty
    case invalid
    case overflow
}

public enum MoneyFormat {
    private static let fractionDigitsCache = OSAllocatedUnfairLock(initialState: [String: Int]())

    public static func fractionDigits(for currencyCode: String) -> Int {
        let code = currencyCode.uppercased()

        if let cached = fractionDigitsCache.withLock({ $0[code] }) {
            return cached
        }

        // NumberFormatter is expensive and not thread-safe; compute once per currency and cache the digits only.
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.currencyCode = code
        let digits = formatter.maximumFractionDigits

        fractionDigitsCache.withLock { state in
            state[code] = digits
        }
        return digits
    }

    public static func decimal(fromMinorUnits minorUnits: Int64, currencyCode: String) -> Decimal {
        let digits = fractionDigits(for: currencyCode)
        return decimal(fromMinorUnits: minorUnits, fractionDigits: digits)
    }

    public static func format(minorUnits: Int64, currencyCode: String, locale: Locale = .current) -> String {
        let code = currencyCode.uppercased()
        let digits = fractionDigits(for: code)
        let decimal = decimal(fromMinorUnits: minorUnits, fractionDigits: digits)
        return decimal.formatted(.currency(code: code).locale(locale))
    }

    public static func parseMinorUnits(
        _ input: String,
        currencyCode: String,
        locale: Locale = .current
    ) -> Result<Int64, MoneyParseError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }

        let posix = Locale(identifier: "en_US_POSIX")
        let fractionDigits = fractionDigits(for: currencyCode)

        func cleaned(_ input: String, locale: Locale) -> String {
            var result =
                input
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: "")
                .replacingOccurrences(of: "\u{202F}", with: "")

            if let grouping = locale.groupingSeparator, !grouping.isEmpty {
                result = result.replacingOccurrences(of: grouping, with: "")
            }

            return result
        }

        let cleanedInput = cleaned(trimmed, locale: locale)
        let decimal =
            Decimal(string: cleanedInput, locale: locale)
            ?? Decimal(string: cleaned(cleanedInput, locale: posix), locale: posix)
            ?? Decimal(string: cleanedInput.replacingOccurrences(of: ",", with: "."), locale: posix)

        guard var decimal else { return .failure(.invalid) }

        var multiplier = Decimal(1)
        for _ in 0..<fractionDigits {
            multiplier *= 10
        }

        decimal *= multiplier
        var rounded = Decimal()
        NSDecimalRound(&rounded, &decimal, 0, .plain)

        let number = NSDecimalNumber(decimal: rounded)
        if number == .notANumber { return .failure(.invalid) }

        let min = NSDecimalNumber(value: Int64.min)
        let max = NSDecimalNumber(value: Int64.max)
        if number.compare(min) == .orderedAscending || number.compare(max) == .orderedDescending {
            return .failure(.overflow)
        }
        return .success(number.int64Value)
    }

    private static func decimal(fromMinorUnits minorUnits: Int64, fractionDigits: Int) -> Decimal {
        var divisor = Decimal(1)
        for _ in 0..<fractionDigits {
            divisor *= 10
        }
        return Decimal(minorUnits) / divisor
    }
}
