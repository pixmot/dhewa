import Foundation
import GRDB
import XCTest

@testable import OrdinatioCore

final class OrdinatioCoreTests: XCTestCase {
    func testMoneyParsingUSD() throws {
        let result = MoneyFormat.parseMinorUnits(
            "12.34", currencyCode: "USD", locale: Locale(identifier: "en_US_POSIX"))
        switch result {
        case .success(let minorUnits):
            XCTAssertEqual(minorUnits, 1234)
        case .failure(let error):
            XCTFail("Unexpected parse error: \(error)")
        }
    }

    func testMoneyParsingJPY() throws {
        let result = MoneyFormat.parseMinorUnits("1234", currencyCode: "JPY", locale: Locale(identifier: "en_US_POSIX"))
        switch result {
        case .success(let minorUnits):
            XCTAssertEqual(minorUnits, 1234)
        case .failure(let error):
            XCTFail("Unexpected parse error: \(error)")
        }
    }

    func testMoneyFormattingUsesCurrency() throws {
        let formatted = MoneyFormat.format(
            minorUnits: -199, currencyCode: "USD", locale: Locale(identifier: "en_US_POSIX"))
        XCTAssertTrue(formatted.contains("$"))
    }

    func testCategoryReorderingPersistsSortOrder() throws {
        let appDatabase = try AppDatabase.inMemory()
        let householdId = try appDatabase.write { db in
            try SeedData.ensureDefaultHouseholdAndCategories(in: db)
        }

        let categories = try appDatabase.read { db in
            try OrdinatioCore.Category
                .filter(OrdinatioCore.Category.Columns.householdId == householdId)
                .filter(OrdinatioCore.Category.Columns.kind == OrdinatioCore.CategoryKind.expense)
                .order(OrdinatioCore.Category.Columns.sortOrder.asc)
                .fetchAll(db)
        }
        XCTAssertGreaterThanOrEqual(categories.count, 3)

        var reordered = categories.map(\.id)
        reordered.replaceSubrange(0..<3, with: reordered.prefix(3).reversed())
        try appDatabase.write { db in
            try CategoryRepository.reorderCategories(in: db, householdId: householdId, orderedCategoryIds: reordered)
        }

        let after = try appDatabase.read { db in
            try OrdinatioCore.Category
                .filter(OrdinatioCore.Category.Columns.householdId == householdId)
                .filter(OrdinatioCore.Category.Columns.kind == OrdinatioCore.CategoryKind.expense)
                .order(OrdinatioCore.Category.Columns.sortOrder.asc)
                .fetchAll(db)
        }
        XCTAssertEqual(after.map(\.id), reordered)
    }

    func testCategoryIconIndexPersists() throws {
        let appDatabase = try AppDatabase.inMemory()
        let householdId = try appDatabase.write { db in
            try SeedData.ensureDefaultHouseholdAndCategories(in: db)
        }

        let now = Date()
        let category = OrdinatioCore.Category(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            kind: .expense,
            name: "Custom",
            iconIndex: 7,
            sortOrder: 99,
            createdAt: now,
            updatedAt: now
        )

        try appDatabase.write { db in
            try category.insert(db)
        }

        let fetched = try appDatabase.read { db in
            try Category.fetchOne(db, key: category.id)
        }
        XCTAssertEqual(fetched?.iconIndex, 7)
    }

    func testBudgetSummariesCountOnlyExpenses() throws {
        let appDatabase = try AppDatabase.inMemory()
        let householdId = try appDatabase.write { db in
            try SeedData.ensureDefaultHouseholdAndCategories(in: db)
        }

        try appDatabase.write { db in
            let now = Date()
            let expenseUsd = Transaction(
                id: UUID().uuidString.lowercased(),
                householdId: householdId,
                categoryId: nil,
                amountMinor: -5000,
                currencyCode: "USD",
                txnDate: 20_260_115,
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
                txnDate: 20_260_116,
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
                txnDate: 20_260_120,
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
                isOverall: true,
                categoryId: nil,
                timeFrame: .month,
                startDate: now,
                currencyCode: "USD",
                amountMinor: 6000
            )
        }

        let budgets = try appDatabase.read { db in
            try BudgetRepository.fetchBudgets(in: db, householdId: householdId)
        }
        XCTAssertEqual(budgets.count, 1)
        XCTAssertTrue(budgets[0].isOverall)
        XCTAssertEqual(budgets[0].currencyCode, "USD")
        XCTAssertEqual(budgets[0].timeFrame, .month)

        let janStart = LocalDate(yyyymmdd: 20_260_101)
        let febStart = LocalDate(yyyymmdd: 20_260_201)

        let spentUsd = try appDatabase.read { db in
            try BudgetRepository.fetchSpentTotal(
                in: db,
                householdId: householdId,
                categoryId: nil,
                currencyCode: "USD",
                startDate: janStart,
                endDate: febStart
            )
        }
        XCTAssertEqual(spentUsd, 5000)

        let spentEur = try appDatabase.read { db in
            try BudgetRepository.fetchSpentTotal(
                in: db,
                householdId: householdId,
                categoryId: nil,
                currencyCode: "EUR",
                startDate: janStart,
                endDate: febStart
            )
        }
        XCTAssertEqual(spentEur, 700)
    }
}
