import Foundation
import Observation
import OrdinatioCore

@MainActor
@Observable
final class TransactionListViewModel {
    var sections: [TransactionSection] = []
    var categories: [OrdinatioCore.Category] = []
    var availableCurrencyCodes: [String] = []

    var filter = TransactionFilter() {
        didSet { scheduleTransactionObservation(debounce: false) }
    }

    var searchText = "" {
        didSet { scheduleTransactionObservation(debounce: true) }
    }

    var errorMessage: String?

    var summaryCurrencyCode: String?
    var netTotalMinor: Int64?
    var incomeTotalMinor: Int64?
    var expenseTotalAbsMinor: Int64?
    var sparklineValues: [Int64] = []

    private let db: DatabaseClient
    private let householdId: String
    private let defaultCurrencyCode: String

    @ObservationIgnored private var categoriesTask: Task<Void, Never>?
    @ObservationIgnored private var transactionsTask: Task<Void, Never>?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?

    init(db: DatabaseClient, householdId: String, defaultCurrencyCode: String) {
        self.db = db
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode.uppercased()
        self.summaryCurrencyCode = defaultCurrencyCode.uppercased()

        startObservingCategories()
        scheduleTransactionObservation(debounce: false)
    }

    deinit {
        categoriesTask?.cancel()
        transactionsTask?.cancel()
        debounceTask?.cancel()
    }

    private func startObservingCategories() {
        categoriesTask?.cancel()

        let db = db
        let householdId = householdId

        categoriesTask = Task.detached(priority: .userInitiated) { [db, householdId] in
            do {
                for try await categories in await db.observeCategories(householdId: householdId) {
                    await MainActor.run { [weak self] in
                        self?.categories = categories
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = ErrorDisplay.message(error)
                }
            }
        }
    }

    private func scheduleTransactionObservation(debounce: Bool) {
        debounceTask?.cancel()

        let filterSnapshot = filter
        let searchSnapshot = searchText

        debounceTask = Task { [weak self] in
            guard let self else { return }

            if debounce {
                do {
                    try await Task.sleep(for: .milliseconds(250))
                    try Task.checkCancellation()
                } catch {
                    return
                }
            }

            var effectiveFilter = filterSnapshot
            effectiveFilter.searchText = searchSnapshot
            startObservingTransactions(filter: effectiveFilter)
        }
    }

    private func startObservingTransactions(filter: TransactionFilter) {
        transactionsTask?.cancel()

        let db = db
        let householdId = householdId
        let defaultCurrencyCode = defaultCurrencyCode

        transactionsTask = Task.detached(priority: .userInitiated) { [db, householdId, defaultCurrencyCode] in
            do {
                for try await rows in await db.observeTransactionListRows(householdId: householdId, filter: filter) {
                    let computed = TransactionListComputation.compute(
                        rows: rows,
                        filter: filter,
                        defaultCurrencyCode: defaultCurrencyCode
                    )
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        self.sections = computed.sections
                        self.availableCurrencyCodes = computed.availableCurrencyCodes
                        self.summaryCurrencyCode = computed.summaryCurrencyCode
                        self.netTotalMinor = computed.netTotalMinor
                        self.incomeTotalMinor = computed.incomeTotalMinor
                        self.expenseTotalAbsMinor = computed.expenseTotalAbsMinor
                        self.sparklineValues = computed.sparklineValues
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = ErrorDisplay.message(error)
                }
            }
        }
    }
}

enum TransactionListComputation {
    struct Result: Sendable {
        var sections: [TransactionSection]
        var availableCurrencyCodes: [String]
        var summaryCurrencyCode: String?
        var netTotalMinor: Int64?
        var incomeTotalMinor: Int64?
        var expenseTotalAbsMinor: Int64?
        var sparklineValues: [Int64]
    }

    static func compute(
        rows: [TransactionListRow],
        filter: TransactionFilter,
        defaultCurrencyCode: String
    ) -> Result {
        let currencyFilter = filter.currencyCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let currencies = Set(rows.map { $0.currencyCode.uppercased() })
        let availableCurrencyCodes = Array(currencies).sorted()

        let summaryCurrencyCode: String?
        if !currencyFilter.isEmpty {
            summaryCurrencyCode = currencyFilter.uppercased()
        } else if let single = currencies.onlyElement {
            summaryCurrencyCode = single
        } else if rows.isEmpty {
            summaryCurrencyCode = defaultCurrencyCode.uppercased()
        } else {
            summaryCurrencyCode = nil
        }

        var netTotalMinor: Int64?
        var incomeTotalMinor: Int64?
        var expenseTotalAbsMinor: Int64?

        if let summaryCurrencyCode {
            var net: Int64 = 0
            var income: Int64 = 0
            var expenseAbs: Int64 = 0
            var hasAny = false

            for row in rows where row.currencyCode.uppercased() == summaryCurrencyCode {
                hasAny = true
                net += row.amountMinor
                if row.amountMinor > 0 {
                    income += row.amountMinor
                } else if row.amountMinor < 0 {
                    expenseAbs += abs(row.amountMinor)
                }
            }

            if hasAny {
                netTotalMinor = net
                incomeTotalMinor = income
                expenseTotalAbsMinor = expenseAbs
            }
        }

        var sections: [TransactionSection] = []
        var currentDate: Int32?
        var currentRows: [TransactionListRow] = []
        var currentNetTotalMinor: Int64 = 0
        var currentNetHasSummaryCurrency = false

        func finalizeSection() {
            guard let currentDate else { return }
            let netTotalMinor = currentNetHasSummaryCurrency ? currentNetTotalMinor : nil
            sections.append(
                TransactionSection(
                    date: LocalDate(yyyymmdd: currentDate),
                    rows: currentRows,
                    netTotalMinor: netTotalMinor
                )
            )
        }

        for row in rows {
            if currentDate != row.txnDate {
                finalizeSection()
                currentDate = row.txnDate
                currentRows = [row]
                currentNetTotalMinor = 0
                currentNetHasSummaryCurrency = false
            } else {
                currentRows.append(row)
            }

            if let summaryCurrencyCode, row.currencyCode.uppercased() == summaryCurrencyCode {
                currentNetTotalMinor += row.amountMinor
                currentNetHasSummaryCurrency = true
            }
        }

        finalizeSection()

        let sparklineValues: [Int64]
        if summaryCurrencyCode == nil || netTotalMinor == nil {
            sparklineValues = []
        } else {
            sparklineValues = sections.prefix(14).reversed().map { $0.netTotalMinor ?? 0 }
        }

        return Result(
            sections: sections,
            availableCurrencyCodes: availableCurrencyCodes,
            summaryCurrencyCode: summaryCurrencyCode,
            netTotalMinor: netTotalMinor,
            incomeTotalMinor: incomeTotalMinor,
            expenseTotalAbsMinor: expenseTotalAbsMinor,
            sparklineValues: sparklineValues
        )
    }
}

private extension Set {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
