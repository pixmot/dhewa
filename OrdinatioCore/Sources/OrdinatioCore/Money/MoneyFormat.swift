import Foundation

public enum MoneyParseError: Error, Equatable {
    case empty
    case invalid
    case overflow
}

public enum MoneyFormat {
    public static func fractionDigits(for currencyCode: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.currencyCode = currencyCode.uppercased()
        return formatter.maximumFractionDigits
    }

    public static func decimal(fromMinorUnits minorUnits: Int64, currencyCode: String) -> Decimal {
        let fractionDigits = fractionDigits(for: currencyCode)
        var divisor = Decimal(1)
        for _ in 0..<fractionDigits {
            divisor *= 10
        }
        return Decimal(minorUnits) / divisor
    }

    public static func format(minorUnits: Int64, currencyCode: String, locale: Locale = .current) -> String {
        let decimal = decimal(fromMinorUnits: minorUnits, currencyCode: currencyCode)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode.uppercased()
        formatter.minimumFractionDigits = fractionDigits(for: currencyCode)
        formatter.maximumFractionDigits = fractionDigits(for: currencyCode)
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "\(minorUnits)"
    }

    public static func parseMinorUnits(
        _ input: String,
        currencyCode: String,
        locale: Locale = .current
    ) -> Result<Int64, MoneyParseError> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }

        let fractionDigits = fractionDigits(for: currencyCode)

        func parseDecimal(locale: Locale) -> Decimal? {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = locale
            formatter.generatesDecimalNumbers = true
            formatter.isLenient = true
            return (formatter.number(from: trimmed) as? NSDecimalNumber)?.decimalValue
        }

        let decimal =
            parseDecimal(locale: locale)
            ?? parseDecimal(locale: Locale(identifier: "en_US_POSIX"))
            ?? {
                let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.generatesDecimalNumbers = true
                return (formatter.number(from: normalized) as? NSDecimalNumber)?.decimalValue
            }()

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
}

