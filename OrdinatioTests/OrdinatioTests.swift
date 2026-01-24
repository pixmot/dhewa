import OrdinatioCore
import XCTest

@testable import Ordinatio

final class TransactionListComputationTests: XCTestCase {
    private func makeRow(
        id: String,
        amountMinor: Int64,
        currencyCode: String,
        txnDate: Int32
    ) -> TransactionListRow {
        TransactionListRow(
            id: id,
            householdId: "household",
            categoryId: nil,
            categoryName: nil,
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            txnDate: txnDate,
            note: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func testCompute_defaultsToDefaultCurrencyAndGroupsSections() {
        let rows: [TransactionListRow] = [
            makeRow(id: "t1", amountMinor: -500, currencyCode: "usd", txnDate: 20_240_102),
            makeRow(id: "t2", amountMinor: 1000, currencyCode: "USD", txnDate: 20_240_102),
            makeRow(id: "t3", amountMinor: -200, currencyCode: "EUR", txnDate: 20_240_101),
            makeRow(id: "t4", amountMinor: -300, currencyCode: "USD", txnDate: 20_240_101),
        ]

        let result = TransactionListComputation.compute(
            rows: rows,
            filter: TransactionFilter(),
            defaultCurrencyCode: "usd"
        )

        XCTAssertEqual(result.summaryCurrencyCode, "USD")
        XCTAssertEqual(result.availableCurrencyCodes, ["EUR", "USD"])
        XCTAssertEqual(result.netTotalMinor, 200)
        XCTAssertEqual(result.incomeTotalMinor, 1000)
        XCTAssertEqual(result.expenseTotalAbsMinor, 800)

        XCTAssertEqual(result.sections.count, 2)
        XCTAssertEqual(result.sections[0].date.yyyymmdd, 20_240_102)
        XCTAssertEqual(result.sections[0].rows.map(\.id), ["t1", "t2"])
        XCTAssertEqual(result.sections[1].date.yyyymmdd, 20_240_101)
        XCTAssertEqual(result.sections[1].rows.map(\.id), ["t3", "t4"])
    }

    func testCompute_usesCurrencyFilterForTotals() {
        let rows: [TransactionListRow] = [
            makeRow(id: "t1", amountMinor: -500, currencyCode: "USD", txnDate: 20_240_102),
            makeRow(id: "t2", amountMinor: 1000, currencyCode: "USD", txnDate: 20_240_102),
            makeRow(id: "t3", amountMinor: -200, currencyCode: "eur", txnDate: 20_240_101),
        ]

        let result = TransactionListComputation.compute(
            rows: rows,
            filter: TransactionFilter(currencyCode: " eur "),
            defaultCurrencyCode: "usd"
        )

        XCTAssertEqual(result.summaryCurrencyCode, "EUR")
        XCTAssertEqual(result.netTotalMinor, -200)
        XCTAssertEqual(result.incomeTotalMinor, 0)
        XCTAssertEqual(result.expenseTotalAbsMinor, 200)
    }
}
