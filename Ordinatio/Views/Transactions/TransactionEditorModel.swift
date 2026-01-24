import Foundation
import Observation
import OrdinatioCore

@MainActor
@Observable
final class TransactionEditorModel {
    var isExpense: Bool
    var amountText: String
    var currencyCode: String
    var fractionDigits: Int
    var dateTime: Date
    var categoryId: String?
    var note: String

    var errorMessage: String?
    var confirmDelete = false
    var showingCategoryPicker = false
    var showingCurrencyPicker = false
    var showingDatePicker = false
    var showingTimePicker = false

    init(
        defaultCurrencyCode: String,
        mode: TransactionEditorMode,
        prefilledCategoryId: String?
    ) {
        switch mode {
        case .create:
            isExpense = true
            amountText = ""
            currencyCode = defaultCurrencyCode.uppercased()
            fractionDigits = MoneyFormat.fractionDigits(for: defaultCurrencyCode)
            dateTime = Date()
            categoryId = prefilledCategoryId
            note = ""
        case .edit(let row):
            isExpense = row.amountMinor < 0
            amountText = Self.entryAmountText(absMinor: abs(row.amountMinor), currencyCode: row.currencyCode)
            currencyCode = row.currencyCode.uppercased()
            fractionDigits = MoneyFormat.fractionDigits(for: row.currencyCode)
            dateTime = Self.initialDateTime(txnDate: row.txnDate, createdAt: row.createdAt)
            categoryId = row.categoryId
            note = row.note ?? ""
        }
    }

    func didSelectCurrency() {
        fractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
        normalizeAmountTextForCurrency()
    }

    var parsedAbsMinor: Int64? {
        Self.parseAbsMinor(from: amountText, fractionDigits: fractionDigits)
    }

    var formattedAmount: String {
        guard let parsedAbsMinor else {
            return fractionDigits == 0 ? "0" : "0." + String(repeating: "0", count: fractionDigits)
        }
        return Self.format(absMinor: parsedAbsMinor, fractionDigits: fractionDigits)
    }

    private static let currencySymbolFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter
    }()

    var currencySymbol: String {
        Self.currencySymbolFormatter.currencyCode = currencyCode.uppercased()
        return Self.currencySymbolFormatter.currencySymbol ?? currencyCode.uppercased()
    }

    var canSave: Bool {
        (parsedAbsMinor ?? 0) > 0
    }

    func appendDigit(_ digit: Int) {
        guard (0...9).contains(digit) else { return }
        let separator = "."

        var next =
            amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        if next == "0" && !next.contains(separator) {
            next = "\(digit)"
            amountText = next
            return
        }

        if let separatorIndex = next.firstIndex(of: Character(separator)) {
            let fractionCount = next.distance(from: next.index(after: separatorIndex), to: next.endIndex)
            guard fractionCount < fractionDigits else { return }
        }

        if next.isEmpty {
            amountText = "\(digit)"
            return
        }

        amountText = next + "\(digit)"
    }

    func appendDecimalSeparator() {
        guard fractionDigits > 0 else { return }
        let separator = "."

        var next =
            amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        guard !next.contains(separator) else { return }
        if next.isEmpty { next = "0" }
        amountText = next + separator
    }

    func deleteLastInput() {
        var next =
            amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        guard !next.isEmpty else { return }

        next.removeLast()
        amountText = next
    }

    private static func entryAmountText(absMinor: Int64, currencyCode: String) -> String {
        let digits = MoneyFormat.fractionDigits(for: currencyCode)
        return format(absMinor: absMinor, fractionDigits: digits)
    }

    private static func initialDateTime(txnDate: Int32, createdAt: Date) -> Date {
        let calendar = Calendar.current
        let day = LocalDate(yyyymmdd: txnDate).date(calendar: calendar)
        let time = calendar.dateComponents([.hour, .minute, .second], from: createdAt)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: day
        ) ?? createdAt
    }

    private static func pow10Int64(_ digits: Int) -> Int64? {
        guard digits >= 0 else { return nil }
        var value: Int64 = 1
        for _ in 0..<digits {
            let (next, overflow) = value.multipliedReportingOverflow(by: 10)
            if overflow { return nil }
            value = next
        }
        return value
    }

    private static func format(absMinor: Int64, fractionDigits: Int) -> String {
        guard let multiplier = pow10Int64(fractionDigits), multiplier > 0 else { return "" }

        if fractionDigits == 0 {
            return String(absMinor)
        }

        let whole = absMinor / multiplier
        let fraction = absMinor % multiplier
        let fractionText = String(fraction)
        let zeros = String(repeating: "0", count: max(0, fractionDigits - fractionText.count))
        return "\(whole).\(zeros)\(fractionText)"
    }

    private static func parseAbsMinor(from input: String, fractionDigits: Int) -> Int64? {
        let trimmed =
            input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        guard !trimmed.isEmpty else { return nil }
        guard let multiplier = pow10Int64(fractionDigits), multiplier > 0 else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        let wholePart = parts.first ?? ""
        let fractionPart = parts.count == 2 ? parts[1] : ""

        guard wholePart.allSatisfy({ $0.isNumber }) else { return nil }
        guard fractionPart.allSatisfy({ $0.isNumber }) else { return nil }

        let whole: Int64
        if wholePart.isEmpty {
            whole = 0
        } else {
            guard let parsedWhole = Int64(wholePart) else { return nil }
            whole = parsedWhole
        }
        if fractionDigits == 0 {
            return whole
        }

        let fractionPrefix = fractionPart.prefix(fractionDigits)
        let fractionPadded = String(fractionPrefix).padding(toLength: fractionDigits, withPad: "0", startingAt: 0)
        guard let fraction = Int64(fractionPadded) else { return nil }

        let (scaledWhole, overflow1) = whole.multipliedReportingOverflow(by: multiplier)
        if overflow1 { return nil }
        let (total, overflow2) = scaledWhole.addingReportingOverflow(fraction)
        if overflow2 { return nil }
        return total
    }

    private func normalizeAmountTextForCurrency() {
        let separator = "."
        var next =
            amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        if fractionDigits == 0 {
            if let idx = next.firstIndex(of: Character(separator)) {
                next = String(next[..<idx])
            }
            amountText = next
            return
        }

        if let idx = next.firstIndex(of: Character(separator)) {
            let fraction = next[next.index(after: idx)...]
            if fraction.count > fractionDigits {
                let end = fraction.index(fraction.startIndex, offsetBy: fractionDigits)
                amountText = String(next[..<next.index(after: idx)]) + fraction[..<end]
            } else {
                amountText = next
            }
            return
        }

        amountText = next
    }
}

