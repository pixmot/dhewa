import Foundation
import GRDB

public enum BudgetRepository {
    public static func observeBudgets(householdId: String) -> ValueObservation<ValueReducers.Fetch<[Budget]>> {
        ValueObservation.tracking { db in
            try fetchBudgets(in: db, householdId: householdId)
        }
    }

    public static func fetchBudgets(in db: Database, householdId: String) throws -> [Budget] {
        try Budget
            .filter(Budget.Columns.householdId == householdId)
            .filter(Budget.Columns.deletedAt == nil)
            .order(Budget.Columns.isOverall.desc, Budget.Columns.createdAt.asc)
            .fetchAll(db)
    }

    public static func upsertBudget(
        in db: Database,
        householdId: String,
        isOverall: Bool,
        categoryId: String?,
        timeFrame: BudgetTimeFrame,
        startDate: Date,
        currencyCode: String,
        amountMinor: Int64
    ) throws {
        let now = Date()
        let currencyCode = currencyCode.uppercased()

        if isOverall {
            try db.execute(
                sql: """
                    UPDATE budgets
                    SET time_frame = ?, start_date = ?, currency_code = ?, amount_minor = ?, updated_at = ?
                    WHERE household_id = ? AND is_overall = 1 AND deleted_at IS NULL
                    """,
                arguments: [timeFrame.rawValue, startDate, currencyCode, amountMinor, now, householdId]
            )
        } else if let categoryId {
            try db.execute(
                sql: """
                    UPDATE budgets
                    SET time_frame = ?, start_date = ?, currency_code = ?, amount_minor = ?, updated_at = ?
                    WHERE household_id = ? AND category_id = ? AND is_overall = 0 AND deleted_at IS NULL
                    """,
                arguments: [timeFrame.rawValue, startDate, currencyCode, amountMinor, now, householdId, categoryId]
            )
        }

        if db.changesCount == 0 {
            let budget = Budget(
                id: UUID().uuidString.lowercased(),
                householdId: householdId,
                isOverall: isOverall,
                categoryId: categoryId,
                timeFrameRaw: timeFrame.rawValue,
                startDate: startDate,
                currencyCode: currencyCode,
                amountMinor: amountMinor,
                createdAt: now,
                updatedAt: now
            )
            try budget.insert(db)
        }
    }

    public static func updateBudget(
        in db: Database,
        budgetId: String,
        isOverall: Bool,
        categoryId: String?,
        timeFrame: BudgetTimeFrame,
        startDate: Date,
        currencyCode: String,
        amountMinor: Int64
    ) throws {
        let now = Date()
        let currencyCode = currencyCode.uppercased()
        let finalCategoryId = isOverall ? nil : categoryId

        try db.execute(
            sql: """
                UPDATE budgets
                SET is_overall = ?, category_id = ?, time_frame = ?, start_date = ?, currency_code = ?, amount_minor = ?, updated_at = ?
                WHERE id = ?
                """,
            arguments: [
                isOverall, finalCategoryId, timeFrame.rawValue, startDate, currencyCode, amountMinor, now, budgetId,
            ]
        )
    }

    public static func updateBudgetStartDate(in db: Database, budgetId: String, startDate: Date) throws {
        try db.execute(
            sql: "UPDATE budgets SET start_date = ?, updated_at = ? WHERE id = ?",
            arguments: [startDate, Date(), budgetId]
        )
    }

    public static func deleteBudget(in db: Database, budgetId: String) throws {
        try db.execute(sql: "DELETE FROM budgets WHERE id = ?", arguments: [budgetId])
    }

    public static func fetchSpentTotal(
        in db: Database,
        householdId: String,
        categoryId: String?,
        currencyCode: String,
        startDate: LocalDate,
        endDate: LocalDate
    ) throws -> Int64 {
        var sql = """
            SELECT COALESCE(SUM(CASE WHEN amount_minor < 0 THEN -amount_minor ELSE 0 END), 0) AS spentAbsMinor
            FROM transactions
            WHERE household_id = ?
              AND deleted_at IS NULL
              AND currency_code = ?
              AND txn_date >= ?
              AND txn_date < ?
            """

        var args: [DatabaseValueConvertible] = [
            householdId,
            currencyCode.uppercased(),
            startDate.yyyymmdd,
            endDate.yyyymmdd,
        ]

        if let categoryId {
            sql += "\n  AND category_id = ?"
            args.append(categoryId)
        }

        struct Row: FetchableRecord, Decodable {
            var spentAbsMinor: Int64
        }

        return try SQLRequest<Row>(sql: sql, arguments: StatementArguments(args))
            .fetchOne(db)?
            .spentAbsMinor ?? 0
    }
}
