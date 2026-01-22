import Foundation
import OrdinatioCore

enum ExportService {
    enum ExportError: Error {
        case utf8EncodingFailed
    }

    static func exportTransactionsCSV(database: AppDatabase, householdId: String) throws -> URL {
        let rows = try database.read { db in
            try TransactionRepository
                .transactionListRequest(householdId: householdId, filter: TransactionFilter())
                .fetchAll(db)
        }

        var lines: [String] = []
        lines.append([
            "txn_date",
            "amount_minor",
            "currency_code",
            "category",
            "note",
            "created_at",
            "updated_at",
        ].joined(separator: ","))

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for row in rows {
            let localDate = LocalDate(yyyymmdd: row.txnDate)
            let dateString = String(format: "%04d-%02d-%02d", localDate.year, localDate.month, localDate.day)

            let fields: [String] = [
                dateString,
                "\(row.amountMinor)",
                row.currencyCode,
                row.categoryName ?? "",
                row.note ?? "",
                iso.string(from: row.createdAt),
                iso.string(from: row.updatedAt),
            ]
            lines.append(fields.map(csvEscape).joined(separator: ","))
        }

        let csv = lines.joined(separator: "\n") + "\n"

        let filename = "transactions-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        guard let data = csv.data(using: .utf8) else { throw ExportError.utf8EncodingFailed }
        try data.write(to: url, options: [.atomic])
        return url
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let doubled = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return value
    }
}
