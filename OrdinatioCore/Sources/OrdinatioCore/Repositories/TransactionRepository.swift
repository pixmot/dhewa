import Foundation
import GRDB

public enum TransactionRepository {
    public static func observeTransactionListRows(householdId: String, filter: TransactionFilter) -> ValueObservation<ValueReducers.Fetch<[TransactionListRow]>> {
        ValueObservation.tracking { db in
            try transactionListRequest(householdId: householdId, filter: filter).fetchAll(db)
        }
    }

    public static func fetchTransaction(in db: Database, id: String) throws -> Transaction? {
        try Transaction.fetchOne(db, key: id)
    }

    public static func upsertTransaction(in db: Database, transaction: Transaction) throws {
        try transaction.save(db)
    }

    public static func deleteTransaction(in db: Database, transactionId: String) throws {
        try db.execute(sql: "DELETE FROM transactions WHERE id = ?", arguments: [transactionId])
    }

    public static func transactionListRequest(householdId: String, filter: TransactionFilter) -> SQLRequest<TransactionListRow> {
        var sql = """
        SELECT
            t.id,
            t.household_id AS householdId,
            t.category_id AS categoryId,
            c.name AS categoryName,
            t.amount_minor AS amountMinor,
            t.currency_code AS currencyCode,
            t.txn_date AS txnDate,
            t.note,
            t.created_at AS createdAt,
            t.updated_at AS updatedAt
        FROM transactions t
        LEFT JOIN categories c ON c.id = t.category_id
        WHERE t.household_id = ?
          AND t.deleted_at IS NULL
        """

        var args: [DatabaseValueConvertible] = [householdId]

        if let categoryId = filter.categoryId {
            sql += "\n  AND t.category_id = ?"
            args.append(categoryId)
        }
        if let currencyCode = filter.currencyCode, !currencyCode.isEmpty {
            sql += "\n  AND t.currency_code = ?"
            args.append(currencyCode.uppercased())
        }
        if let minAmount = filter.minAbsAmountMinor {
            sql += "\n  AND ABS(t.amount_minor) >= ?"
            args.append(minAmount)
        }
        if let maxAmount = filter.maxAbsAmountMinor {
            sql += "\n  AND ABS(t.amount_minor) <= ?"
            args.append(maxAmount)
        }
        let search = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty {
            sql += "\n  AND (t.note LIKE ? COLLATE NOCASE)"
            args.append("%\(search)%")
        }

        sql += "\nORDER BY t.txn_date DESC, t.created_at DESC"

        return SQLRequest(sql: sql, arguments: StatementArguments(args))
    }
}
