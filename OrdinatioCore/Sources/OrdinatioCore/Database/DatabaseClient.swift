import Foundation
import GRDB

/// Serializes all database access behind an actor so UI code can `await` without blocking the main actor.
public actor DatabaseClient {
    private let database: AppDatabase
    private static let observationQueue = DispatchQueue(label: "OrdinatioCore.DatabaseClient.observation")

    public init(database: AppDatabase) {
        self.database = database
    }

    public func ensureSeedData() throws -> String {
        try database.write { db in
            try SeedData.ensureDefaultHouseholdAndCategories(in: db)
        }
    }

    public func fetchCategories(householdId: String) throws -> [Category] {
        try database.read { db in
            try Category
                .filter(Category.Columns.householdId == householdId)
                .filter(Category.Columns.deletedAt == nil)
                .order(Category.Columns.sortOrder.asc)
                .fetchAll(db)
        }
    }

    public func createCategory(householdId: String, name: String) throws -> Category {
        try database.write { db in
            try CategoryRepository.createCategory(in: db, householdId: householdId, name: name)
        }
    }

    public func updateCategoryName(categoryId: String, name: String) throws {
        try database.write { db in
            try CategoryRepository.updateCategoryName(in: db, categoryId: categoryId, name: name)
        }
    }

    public func deleteCategory(categoryId: String) throws {
        try database.write { db in
            try CategoryRepository.deleteCategory(in: db, categoryId: categoryId)
        }
    }

    public func reorderCategories(householdId: String, orderedCategoryIds: [String]) throws {
        try database.write { db in
            try CategoryRepository.reorderCategories(in: db, householdId: householdId, orderedCategoryIds: orderedCategoryIds)
        }
    }

    public func upsertTransaction(_ transaction: Transaction) throws {
        try database.write { db in
            try TransactionRepository.upsertTransaction(in: db, transaction: transaction)
        }
    }

    public func deleteTransaction(transactionId: String) throws {
        try database.write { db in
            try TransactionRepository.deleteTransaction(in: db, transactionId: transactionId)
        }
    }

    public func upsertBudget(
        householdId: String,
        isOverall: Bool,
        categoryId: String?,
        timeFrame: BudgetTimeFrame,
        startDate: Date,
        currencyCode: String,
        amountMinor: Int64
    ) throws {
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
    }

    public func observeCategories(householdId: String) -> AsyncThrowingStream<[Category], Error> {
        stream(CategoryRepository.observeCategories(householdId: householdId))
    }

    public func observeBudgets(householdId: String) -> AsyncThrowingStream<[Budget], Error> {
        stream(BudgetRepository.observeBudgets(householdId: householdId))
    }

    public func observeTransactionListRows(
        householdId: String,
        filter: TransactionFilter
    ) -> AsyncThrowingStream<[TransactionListRow], Error> {
        stream(TransactionRepository.observeTransactionListRows(householdId: householdId, filter: filter))
    }

    private func stream<T: Sendable>(
        _ observation: ValueObservation<ValueReducers.Fetch<[T]>>
    ) -> AsyncThrowingStream<[T], Error> {
        // Keep only the most recent value if a slow consumer falls behind.
        AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                do {
                    for try await value in observation.values(in: database.dbQueue, scheduling: .async(onQueue: Self.observationQueue)) {
                        continuation.yield(value)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
