import Combine
import Foundation
import GRDB
import OrdinatioCore

@MainActor
final class BudgetsViewModel: ObservableObject {
    @Published private(set) var snapshots: [BudgetSnapshot] = []
    @Published private(set) var categories: [OrdinatioCore.Category] = []
    @Published var errorMessage: String?

    private let database: AppDatabase
    private let householdId: String

    private var snapshotsCancellable: AnyCancellable?
    private var categoriesCancellable: AnyCancellable?

    init(database: AppDatabase, householdId: String) {
        self.database = database
        self.householdId = householdId

        startObservingSnapshots()
        startObservingCategories()
        refreshBudgetsForCurrentPeriod()
    }

    var overallSnapshot: BudgetSnapshot? {
        snapshots.first { $0.budget.isOverall }
    }

    var categorySnapshots: [BudgetSnapshot] {
        snapshots.filter { !$0.budget.isOverall }
    }

    private func startObservingSnapshots() {
        snapshotsCancellable?.cancel()
        snapshotsCancellable = ValueObservation.tracking { [self] db -> [BudgetSnapshot] in
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()

            let budgets = try BudgetRepository.fetchBudgets(in: db, householdId: householdId)
            let categories = try OrdinatioCore.Category
                .filter(OrdinatioCore.Category.Columns.householdId == householdId)
                .filter(OrdinatioCore.Category.Columns.deletedAt == nil)
                .fetchAll(db)

            let categoriesById = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })

            return try budgets.map { budget in
                    let period = BudgetDateHelper.period(for: budget)
                    let spent = try BudgetRepository.fetchSpentTotal(
                        in: db,
                        householdId: householdId,
                        categoryId: budget.isOverall ? nil : budget.categoryId,
                        currencyCode: budget.currencyCode,
                        startDate: LocalDate.from(date: period.start),
                        endDate: LocalDate.from(date: min(period.end, tomorrow))
                    )
                    return BudgetSnapshot(
                        budget: budget,
                        category: budget.categoryId.flatMap { categoriesById[$0] },
                        period: period,
                        spentAbsMinor: spent
                    )
                }
        }
        .publisher(in: database.dbQueue)
        .sink { [weak self] completion in
            if case let .failure(error) = completion {
                self?.errorMessage = ErrorDisplay.message(error)
            }
        } receiveValue: { [weak self] snapshots in
            self?.snapshots = snapshots
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

    func refreshBudgetsForCurrentPeriod(referenceDate: Date = Date()) {
        do {
            try database.write { db in
                let budgets = try BudgetRepository.fetchBudgets(in: db, householdId: householdId)
                for budget in budgets {
                    let normalized = BudgetDateHelper.normalizedStartDate(for: budget, referenceDate: referenceDate)
                    let normalizedDay = LocalDate.from(date: normalized).yyyymmdd
                    let currentDay = LocalDate.from(date: budget.startDate).yyyymmdd
                    if normalizedDay != currentDay {
                        try BudgetRepository.updateBudgetStartDate(in: db, budgetId: budget.id, startDate: normalized)
                    }
                }
            }
        } catch {
            errorMessage = ErrorDisplay.message(error)
        }
    }

    func upsertBudget(
        isOverall: Bool,
        categoryId: String?,
        timeFrame: BudgetTimeFrame,
        startDate: Date,
        currencyCode: String,
        amountMinor: Int64
    ) {
        do {
            try database.write { db in
                try BudgetRepository.upsertBudget(
                    in: db,
                    householdId: householdId,
                    isOverall: isOverall,
                    categoryId: categoryId,
                    timeFrame: timeFrame,
                    startDate: startDate,
                    currencyCode: currencyCode,
                    amountMinor: amountMinor
                )
            }
        } catch {
            errorMessage = ErrorDisplay.message(error)
        }
    }

    func updateBudget(
        budgetId: String,
        isOverall: Bool,
        categoryId: String?,
        timeFrame: BudgetTimeFrame,
        startDate: Date,
        currencyCode: String,
        amountMinor: Int64
    ) {
        do {
            try database.write { db in
                try BudgetRepository.updateBudget(
                    in: db,
                    budgetId: budgetId,
                    isOverall: isOverall,
                    categoryId: categoryId,
                    timeFrame: timeFrame,
                    startDate: startDate,
                    currencyCode: currencyCode,
                    amountMinor: amountMinor
                )
            }
        } catch {
            errorMessage = ErrorDisplay.message(error)
        }
    }

    func deleteBudget(id: String) {
        do {
            try database.write { db in
                try BudgetRepository.deleteBudget(in: db, budgetId: id)
            }
        } catch {
            errorMessage = ErrorDisplay.message(error)
        }
    }
}
