import Foundation
import GRDB
import Testing
@testable import OrdinatioCore

@Test func moneyParsingUSD() throws {
    let result = MoneyFormat.parseMinorUnits("12.34", currencyCode: "USD", locale: Locale(identifier: "en_US_POSIX"))
    #expect(result == .success(1234))
}

@Test func moneyParsingJPY() throws {
    let result = MoneyFormat.parseMinorUnits("1234", currencyCode: "JPY", locale: Locale(identifier: "en_US_POSIX"))
    #expect(result == .success(1234))
}

@Test func moneyFormattingUsesCurrency() throws {
    let formatted = MoneyFormat.format(minorUnits: -199, currencyCode: "USD", locale: Locale(identifier: "en_US_POSIX"))
    #expect(formatted.contains("$"))
}

@Test func categoryReorderingPersistsSortOrder() throws {
    let appDatabase = try AppDatabase.inMemory()
    let householdId = try appDatabase.write { db in
        try SeedData.ensureDefaultHouseholdAndCategories(in: db)
    }

    let categories = try appDatabase.read { db in
        try Category
            .filter(Category.Columns.householdId == householdId)
            .order(Category.Columns.sortOrder.asc)
            .fetchAll(db)
    }
    #expect(categories.count >= 3)

    var reordered = categories.map(\.id)
    reordered.replaceSubrange(0..<3, with: reordered.prefix(3).reversed())
    try appDatabase.write { db in
        try CategoryRepository.reorderCategories(in: db, householdId: householdId, orderedCategoryIds: reordered)
    }

    let after = try appDatabase.read { db in
        try Category
            .filter(Category.Columns.householdId == householdId)
            .order(Category.Columns.sortOrder.asc)
            .fetchAll(db)
    }
    #expect(after.map(\.id) == reordered)
}

@Test func budgetSummariesCountOnlyExpenses() throws {
    let appDatabase = try AppDatabase.inMemory()
    let householdId = try appDatabase.write { db in
        try SeedData.ensureDefaultHouseholdAndCategories(in: db)
    }
    let month = YearMonth(year: 2026, month: 1)

    try appDatabase.write { db in
        let now = Date()
        let expenseUsd = Transaction(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            categoryId: nil,
            amountMinor: -5000,
            currencyCode: "USD",
            txnDate: 20260115,
            note: "Dinner",
            createdAt: now,
            updatedAt: now
        )
        let incomeUsd = Transaction(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            categoryId: nil,
            amountMinor: 10_000,
            currencyCode: "USD",
            txnDate: 20260116,
            note: "Salary",
            createdAt: now,
            updatedAt: now
        )
        let expenseEur = Transaction(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            categoryId: nil,
            amountMinor: -700,
            currencyCode: "EUR",
            txnDate: 20260120,
            note: "Coffee",
            createdAt: now,
            updatedAt: now
        )

        try expenseUsd.insert(db)
        try incomeUsd.insert(db)
        try expenseEur.insert(db)

        try BudgetRepository.upsertBudget(in: db, householdId: householdId, month: month, currencyCode: "USD", amountMinor: 6000)
    }

    let summaries = try appDatabase.read { db in
        try BudgetRepository.fetchCurrencySummaries(in: db, householdId: householdId, month: month)
    }

    let usd = summaries.first(where: { $0.currencyCode == "USD" })
    #expect(usd?.spentAbsMinor == 5000)
    #expect(usd?.budgetMinor == 6000)

    let eur = summaries.first(where: { $0.currencyCode == "EUR" })
    #expect(eur?.spentAbsMinor == 700)
    #expect(eur?.budgetMinor == nil)
}
