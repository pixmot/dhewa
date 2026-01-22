import Combine
import Foundation
import OrdinatioCore

@MainActor
final class BudgetsViewModel: ObservableObject {
    @Published private(set) var summaries: [CurrencyBudgetSummary] = []
    @Published var month: YearMonth
    @Published var errorMessage: String?

    private let database: AppDatabase
    private let householdId: String

    private var summariesCancellable: AnyCancellable?
    private var monthCancellable: AnyCancellable?

    init(database: AppDatabase, householdId: String, month: YearMonth = .current()) {
        self.database = database
        self.householdId = householdId
        self.month = month

        startObservingSummaries()
        monthCancellable = $month.dropFirst().sink { [weak self] _ in
            self?.startObservingSummaries()
        }
    }

    func previousMonth() {
        let year = month.year
        let m = month.month
        if m == 1 {
            month = YearMonth(year: year - 1, month: 12)
        } else {
            month = YearMonth(year: year, month: m - 1)
        }
    }

    func nextMonth() {
        month = month.next()
    }

    private func startObservingSummaries() {
        summariesCancellable?.cancel()
        summariesCancellable = BudgetRepository
            .observeCurrencySummaries(householdId: householdId, month: month)
            .publisher(in: database.dbQueue)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] summaries in
                self?.summaries = summaries
            }
    }

    func upsertBudget(currencyCode: String, amountMinor: Int64) {
        do {
            try database.write { db in
                try BudgetRepository.upsertBudget(in: db, householdId: householdId, month: month, currencyCode: currencyCode, amountMinor: amountMinor)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteBudget(currencyCode: String) {
        do {
            try database.write { db in
                try BudgetRepository.deleteBudget(in: db, householdId: householdId, month: month, currencyCode: currencyCode)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
