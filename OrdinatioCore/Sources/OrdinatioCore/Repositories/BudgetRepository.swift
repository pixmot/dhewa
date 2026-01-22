import Foundation
import GRDB

public struct CurrencyBudgetSummary: Hashable, Sendable {
    public var currencyCode: String
    public var spentAbsMinor: Int64
    public var budgetMinor: Int64?

    public init(currencyCode: String, spentAbsMinor: Int64, budgetMinor: Int64?) {
        self.currencyCode = currencyCode
        self.spentAbsMinor = spentAbsMinor
        self.budgetMinor = budgetMinor
    }
}

public enum BudgetRepository {
    public static func observeCurrencySummaries(householdId: String, month: YearMonth) -> ValueObservation<ValueReducers.Fetch<[CurrencyBudgetSummary]>> {
        ValueObservation.tracking { db in
            try fetchCurrencySummariesInternal(in: db, householdId: householdId, month: month)
        }
    }

    public static func fetchCurrencySummaries(in db: Database, householdId: String, month: YearMonth) throws -> [CurrencyBudgetSummary] {
        try fetchCurrencySummariesInternal(in: db, householdId: householdId, month: month)
    }

    public static func upsertBudget(in db: Database, householdId: String, month: YearMonth, currencyCode: String, amountMinor: Int64) throws {
        let now = Date()
        let currencyCode = currencyCode.uppercased()

        try db.execute(
            sql: """
            UPDATE budgets
            SET amount_minor = ?, updated_at = ?
            WHERE household_id = ? AND budget_month = ? AND currency_code = ? AND deleted_at IS NULL
            """,
            arguments: [amountMinor, now, householdId, month.yyyymm, currencyCode]
        )
        if db.changesCount == 0 {
            let budget = Budget(
                id: UUID().uuidString.lowercased(),
                householdId: householdId,
                budgetMonth: month.yyyymm,
                currencyCode: currencyCode,
                amountMinor: amountMinor,
                createdAt: now,
                updatedAt: now
            )
            try budget.insert(db)
        }
    }

    public static func deleteBudget(in db: Database, householdId: String, month: YearMonth, currencyCode: String) throws {
        try db.execute(
            sql: "DELETE FROM budgets WHERE household_id = ? AND budget_month = ? AND currency_code = ?",
            arguments: [householdId, month.yyyymm, currencyCode.uppercased()]
        )
    }

    private static func fetchCurrencySummariesInternal(in db: Database, householdId: String, month: YearMonth) throws -> [CurrencyBudgetSummary] {
        let start = month.yyyymm * 100 + 1
        let end = month.next().yyyymm * 100 + 1

        struct TxnSpentRow: FetchableRecord, Decodable {
            var currencyCode: String
            var spentAbsMinor: Int64
        }

        let spentRows = try SQLRequest<TxnSpentRow>(
            sql: """
            SELECT
                currency_code AS currencyCode,
                COALESCE(SUM(CASE WHEN amount_minor < 0 THEN -amount_minor ELSE 0 END), 0) AS spentAbsMinor
            FROM transactions
            WHERE household_id = ?
              AND deleted_at IS NULL
              AND txn_date >= ?
              AND txn_date < ?
            GROUP BY currency_code
            ORDER BY currency_code ASC
            """,
            arguments: [householdId, start, end]
        ).fetchAll(db)

        struct BudgetRow: FetchableRecord, Decodable {
            var currencyCode: String
            var budgetMinor: Int64
        }

        let budgetRows = try SQLRequest<BudgetRow>(
            sql: """
            SELECT
                currency_code AS currencyCode,
                amount_minor AS budgetMinor
            FROM budgets
            WHERE household_id = ? AND budget_month = ? AND deleted_at IS NULL
            """,
            arguments: [householdId, month.yyyymm]
        ).fetchAll(db)

        let budgetByCurrency = Dictionary(uniqueKeysWithValues: budgetRows.map { ($0.currencyCode, $0.budgetMinor) })

        let spentByCurrency = Dictionary(uniqueKeysWithValues: spentRows.map { ($0.currencyCode, $0.spentAbsMinor) })
        let allCurrencies = Set(spentByCurrency.keys).union(budgetByCurrency.keys)

        return allCurrencies
            .sorted()
            .map { code in
                CurrencyBudgetSummary(
                    currencyCode: code,
                    spentAbsMinor: spentByCurrency[code] ?? 0,
                    budgetMinor: budgetByCurrency[code]
                )
            }
    }
}
