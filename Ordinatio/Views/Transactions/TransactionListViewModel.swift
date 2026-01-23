import Combine
import Foundation
import OrdinatioCore

@MainActor
final class TransactionListViewModel: ObservableObject {
    @Published private(set) var sections: [TransactionSection] = []
    @Published private(set) var categories: [OrdinatioCore.Category] = []
    @Published private(set) var availableCurrencyCodes: [String] = []

    @Published var filter = TransactionFilter()
    @Published var searchText = ""
    @Published var errorMessage: String?

    private let database: AppDatabase
    private let householdId: String

    private var transactionsCancellable: AnyCancellable?
    private var categoriesCancellable: AnyCancellable?
    private var filterCancellable: AnyCancellable?

    init(database: AppDatabase, householdId: String) {
        self.database = database
        self.householdId = householdId

        startObservingCategories()
        startObservingTransactions()
        bindFilterUpdates()
    }

    private func bindFilterUpdates() {
        filterCancellable = Publishers
            .CombineLatest(
                $filter,
                $searchText
                    .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            )
            .sink { [weak self] filter, searchText in
                guard let self else { return }
                var updated = filter
                updated.searchText = searchText
                self.startObservingTransactions(filter: updated)
            }
    }

    private func startObservingCategories() {
        categoriesCancellable?.cancel()
        categoriesCancellable = CategoryRepository
            .observeCategories(householdId: householdId)
            .publisher(in: database.dbQueue)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = ErrorDisplay.message(error)
                }
            } receiveValue: { [weak self] categories in
                self?.categories = categories
            }
    }

    private func startObservingTransactions() {
        var updated = filter
        updated.searchText = searchText
        startObservingTransactions(filter: updated)
    }

    private func startObservingTransactions(filter: TransactionFilter) {
        transactionsCancellable?.cancel()
        transactionsCancellable = TransactionRepository
            .observeTransactionListRows(householdId: householdId, filter: filter)
            .publisher(in: database.dbQueue)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = ErrorDisplay.message(error)
                }
            } receiveValue: { [weak self] rows in
                self?.updateFromRows(rows)
            }
    }

    private func updateFromRows(_ rows: [TransactionListRow]) {
        availableCurrencyCodes = Array(Set(rows.map(\.currencyCode))).sorted()

        var sections: [TransactionSection] = []
        var currentDate: Int32?
        var currentRows: [TransactionListRow] = []

        for row in rows {
            if currentDate != row.txnDate {
                if let currentDate {
                    sections.append(
                        TransactionSection(
                            date: LocalDate(yyyymmdd: currentDate),
                            rows: currentRows
                        )
                    )
                }
                currentDate = row.txnDate
                currentRows = [row]
            } else {
                currentRows.append(row)
            }
        }

        if let currentDate {
            sections.append(
                TransactionSection(
                    date: LocalDate(yyyymmdd: currentDate),
                    rows: currentRows
                )
            )
        }

        self.sections = sections
    }
}
