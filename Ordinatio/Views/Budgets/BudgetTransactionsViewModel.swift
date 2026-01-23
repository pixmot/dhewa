import Combine
import Foundation
import OrdinatioCore

@MainActor
final class BudgetTransactionsViewModel: ObservableObject {
    @Published private(set) var rows: [TransactionListRow] = []
    @Published private(set) var spentAbsMinor: Int64 = 0
    @Published private(set) var earliestTxnDate: Int32?
    @Published var errorMessage: String?

    private let database: AppDatabase
    private let householdId: String
    private var budget: Budget?
    private var currentStartDate: Date = Date()

    private var rowsCancellable: AnyCancellable?
    private var earliestDateCancellable: AnyCancellable?

    init(database: AppDatabase, householdId: String) {
        self.database = database
        self.householdId = householdId
    }

    func deleteTransaction(id: String) {
        do {
            try database.write { db in
                try TransactionRepository.deleteTransaction(in: db, transactionId: id)
            }
        } catch {
            errorMessage = ErrorDisplay.message(error)
        }
    }

    func configure(budget: Budget, startDate: Date) {
        self.budget = budget
        updatePeriod(startDate: startDate)
    }

    func updatePeriod(startDate: Date) {
        currentStartDate = startDate
        startObserving()
    }

    private func startObserving() {
        guard let budget else { return }
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let period = BudgetDateHelper.period(for: budget.timeFrame, startDate: currentStartDate)
        let start = LocalDate.from(date: period.start)
        let end = LocalDate.from(date: min(period.end, tomorrow))

        rowsCancellable?.cancel()
        rowsCancellable = TransactionRepository
            .observeBudgetTransactions(
                householdId: householdId,
                categoryId: budget.isOverall ? nil : budget.categoryId,
                currencyCode: budget.currencyCode,
                startDate: start,
                endDate: end
            )
            .publisher(in: database.dbQueue)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = ErrorDisplay.message(error)
                }
            } receiveValue: { [weak self] rows in
                self?.rows = rows
                let total = rows.reduce(Int64(0)) { partialResult, row in
                    partialResult + abs(row.amountMinor)
                }
                self?.spentAbsMinor = total
            }

        earliestDateCancellable?.cancel()
        earliestDateCancellable = TransactionRepository
            .observeEarliestBudgetTransactionDate(
                householdId: householdId,
                categoryId: budget.isOverall ? nil : budget.categoryId,
                currencyCode: budget.currencyCode
            )
            .publisher(in: database.dbQueue)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = ErrorDisplay.message(error)
                }
            } receiveValue: { [weak self] date in
                self?.earliestTxnDate = date
            }
    }
}
