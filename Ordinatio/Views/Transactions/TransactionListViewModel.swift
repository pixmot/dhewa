import Foundation
import Observation
import OrdinatioCore

enum TransactionSummaryTimeFrame: Int, CaseIterable, Hashable, Sendable, Identifiable {
    case today
    case thisWeek
    case thisMonth
    case thisYear
    case allTime

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .today: "today"
        case .thisWeek: "this week"
        case .thisMonth: "this month"
        case .thisYear: "this year"
        case .allTime: "all time"
        }
    }
}

@MainActor
@Observable
final class TransactionListViewModel {
    var sections: [TransactionSection] = []
    var categories: [OrdinatioCore.Category] = []
    var availableCurrencyCodes: [String] = []

    var summaryTimeFrame: TransactionSummaryTimeFrame = .thisMonth {
        didSet { scheduleTransactionObservation(debounce: false) }
    }

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
        let summaryTimeFrame = summaryTimeFrame

        transactionsTask = Task.detached(priority: .userInitiated) {
            [db, householdId, defaultCurrencyCode, summaryTimeFrame] in
            do {
                for try await rows in await db.observeTransactionListRows(householdId: householdId, filter: filter) {
                    let computed = TransactionListComputation.compute(
                        rows: rows,
                        filter: filter,
                        defaultCurrencyCode: defaultCurrencyCode,
                        summaryTimeFrame: summaryTimeFrame
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
        defaultCurrencyCode: String,
        summaryTimeFrame: TransactionSummaryTimeFrame
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

        let calendar = Calendar.current
        let now = Date()
        let today = LocalDate.from(date: now, calendar: calendar)
        let todayYyyymmdd = today.yyyymmdd

        func startDateYyyymmdd() -> Int32? {
            switch summaryTimeFrame {
            case .today:
                return todayYyyymmdd
            case .thisWeek:
                let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: now)
                guard let start = calendar.date(from: components) else { return nil }
                return LocalDate.from(date: start, calendar: calendar).yyyymmdd
            case .thisMonth:
                let components = calendar.dateComponents([.year, .month], from: now)
                guard let start = calendar.date(from: components) else { return nil }
                return LocalDate.from(date: start, calendar: calendar).yyyymmdd
            case .thisYear:
                let components = calendar.dateComponents([.year], from: now)
                guard let start = calendar.date(from: components) else { return nil }
                return LocalDate.from(date: start, calendar: calendar).yyyymmdd
            case .allTime:
                return nil
            }
        }

        let summaryStartYyyymmdd = startDateYyyymmdd()

        var netTotalMinor: Int64?
        var incomeTotalMinor: Int64?
        var expenseTotalAbsMinor: Int64?

        if let summaryCurrencyCode {
            var net: Int64 = 0
            var income: Int64 = 0
            var expenseAbs: Int64 = 0

            for row in rows where row.currencyCode.uppercased() == summaryCurrencyCode {
                guard row.txnDate <= todayYyyymmdd else { continue }
                if let summaryStartYyyymmdd, row.txnDate < summaryStartYyyymmdd { continue }
                net += row.amountMinor
                if row.amountMinor > 0 {
                    income += row.amountMinor
                } else if row.amountMinor < 0 {
                    expenseAbs += abs(row.amountMinor)
                }
            }

            netTotalMinor = net
            incomeTotalMinor = income
            expenseTotalAbsMinor = expenseAbs
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

        let sparklineValues = SparklineComputation.compute(
            sections: sections,
            summaryCurrencyCode: summaryCurrencyCode,
            netTotalMinor: netTotalMinor,
            summaryTimeFrame: summaryTimeFrame,
            today: today,
            calendar: calendar
        )

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

enum SparklineComputation {
    static func compute(
        sections: [TransactionSection],
        summaryCurrencyCode: String?,
        netTotalMinor: Int64?,
        summaryTimeFrame: TransactionSummaryTimeFrame,
        today: LocalDate,
        calendar: Calendar
    ) -> [Int64] {
        guard summaryCurrencyCode != nil else { return [] }
        guard netTotalMinor != nil else { return [] }

        switch summaryTimeFrame {
        case .thisWeek:
            return dailyCumulative(
                sections: sections,
                startYyyymmdd: startOfWeekYyyymmdd(calendar: calendar, today: today),
                endYyyymmdd: today.yyyymmdd,
                calendar: calendar
            )
        case .thisMonth:
            return dailyCumulative(
                sections: sections,
                startYyyymmdd: startOfMonthYyyymmdd(calendar: calendar, today: today),
                endYyyymmdd: today.yyyymmdd,
                calendar: calendar
            )
        case .thisYear:
            return monthlyCumulative(
                sections: sections,
                startYyyymmdd: startOfYearYyyymmdd(calendar: calendar, today: today),
                endYyyymmdd: today.yyyymmdd,
                calendar: calendar
            )
        case .today, .allTime:
            return []
        }
    }

    private static func dailyCumulative(
        sections: [TransactionSection],
        startYyyymmdd: Int32,
        endYyyymmdd: Int32,
        calendar: Calendar
    ) -> [Int64] {
        guard startYyyymmdd <= endYyyymmdd else { return [] }

        let dayNetByDate = sections.reduce(into: [Int32: Int64]()) { partialResult, section in
            if let net = section.netTotalMinor {
                partialResult[section.date.yyyymmdd] = net
            }
        }

        let startDate = LocalDate(yyyymmdd: startYyyymmdd).date(calendar: calendar)
        let endDate = LocalDate(yyyymmdd: endYyyymmdd).date(calendar: calendar)

        var points: [Int64] = [0]
        var running: Int64 = 0

        var cursor = startDate
        while cursor <= endDate {
            let date = LocalDate.from(date: cursor, calendar: calendar)
            running += dayNetByDate[date.yyyymmdd] ?? 0
            points.append(running)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return points.count > 1 ? points : []
    }

    private static func monthlyCumulative(
        sections: [TransactionSection],
        startYyyymmdd: Int32,
        endYyyymmdd: Int32,
        calendar: Calendar
    ) -> [Int64] {
        guard startYyyymmdd <= endYyyymmdd else { return [] }
        let end = LocalDate(yyyymmdd: endYyyymmdd)
        let start = LocalDate(yyyymmdd: startYyyymmdd)
        guard start <= end else { return [] }

        var netByMonth: [Int: Int64] = [:]
        for section in sections {
            guard section.date >= start, section.date <= end else { continue }
            guard let net = section.netTotalMinor else { continue }
            let key = section.date.year * 100 + section.date.month
            netByMonth[key, default: 0] += net
        }

        let startDate = start.date(calendar: calendar)
        let endDate = end.date(calendar: calendar)

        var points: [Int64] = [0]
        var running: Int64 = 0

        var cursorComponents = calendar.dateComponents([.year, .month], from: startDate)
        cursorComponents.day = 1
        guard var cursor = calendar.date(from: cursorComponents) else { return [] }

        while cursor <= endDate {
            let local = LocalDate.from(date: cursor, calendar: calendar)
            let key = local.year * 100 + local.month
            running += netByMonth[key] ?? 0
            points.append(running)

            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }

        return points.count > 1 ? points : []
    }

    private static func startOfWeekYyyymmdd(calendar: Calendar, today: LocalDate) -> Int32 {
        let todayDate = today.date(calendar: calendar)
        let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: todayDate)
        let start = calendar.date(from: components) ?? todayDate
        return LocalDate.from(date: start, calendar: calendar).yyyymmdd
    }

    private static func startOfMonthYyyymmdd(calendar: Calendar, today: LocalDate) -> Int32 {
        let todayDate = today.date(calendar: calendar)
        let components = calendar.dateComponents([.year, .month], from: todayDate)
        let start = calendar.date(from: components) ?? todayDate
        return LocalDate.from(date: start, calendar: calendar).yyyymmdd
    }

    private static func startOfYearYyyymmdd(calendar: Calendar, today: LocalDate) -> Int32 {
        let todayDate = today.date(calendar: calendar)
        let components = calendar.dateComponents([.year], from: todayDate)
        let start = calendar.date(from: components) ?? todayDate
        return LocalDate.from(date: start, calendar: calendar).yyyymmdd
    }
}

extension Set {
    fileprivate var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
