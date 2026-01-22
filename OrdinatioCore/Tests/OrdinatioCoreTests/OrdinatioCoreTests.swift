import Foundation
import GRDB
import XCTest
@testable import OrdinatioCore

final class OrdinatioCoreTests: XCTestCase {
    func testMoneyParsingUSD() throws {
        let result = MoneyFormat.parseMinorUnits("12.34", currencyCode: "USD", locale: Locale(identifier: "en_US_POSIX"))
        switch result {
        case let .success(minorUnits):
            XCTAssertEqual(minorUnits, 1234)
        case let .failure(error):
            XCTFail("Unexpected parse error: \(error)")
        }
    }

    func testMoneyParsingJPY() throws {
        let result = MoneyFormat.parseMinorUnits("1234", currencyCode: "JPY", locale: Locale(identifier: "en_US_POSIX"))
        switch result {
        case let .success(minorUnits):
            XCTAssertEqual(minorUnits, 1234)
        case let .failure(error):
            XCTFail("Unexpected parse error: \(error)")
        }
    }

    func testMoneyFormattingUsesCurrency() throws {
        let formatted = MoneyFormat.format(minorUnits: -199, currencyCode: "USD", locale: Locale(identifier: "en_US_POSIX"))
        XCTAssertTrue(formatted.contains("$"))
    }

    func testCategoryReorderingPersistsSortOrder() throws {
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
        XCTAssertGreaterThanOrEqual(categories.count, 3)

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
        XCTAssertEqual(after.map(\.id), reordered)
    }

    func testBudgetSummariesCountOnlyExpenses() throws {
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

            try BudgetRepository.upsertBudget(
                in: db,
                householdId: householdId,
                month: month,
                currencyCode: "USD",
                amountMinor: 6000
            )
        }

        let summaries = try appDatabase.read { db in
            try BudgetRepository.fetchCurrencySummaries(in: db, householdId: householdId, month: month)
        }

        let usd = summaries.first(where: { $0.currencyCode == "USD" })
        XCTAssertEqual(usd?.spentAbsMinor, 5000)
        XCTAssertEqual(usd?.budgetMinor, 6000)

        let eur = summaries.first(where: { $0.currencyCode == "EUR" })
        XCTAssertEqual(eur?.spentAbsMinor, 700)
        XCTAssertNil(eur?.budgetMinor)
    }
}
