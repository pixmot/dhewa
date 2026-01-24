import Foundation
import GRDB

/// Serializes all database access behind an actor so UI code can `await` without blocking the main actor.
public actor DatabaseClient {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func ensureSeedData() throws -> String {
        try database.write { db in
            try SeedData.ensureDefaultHouseholdAndCategories(in: db)
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
                    for try await value in observation.values(in: database.dbQueue, scheduling: .immediate) {
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
