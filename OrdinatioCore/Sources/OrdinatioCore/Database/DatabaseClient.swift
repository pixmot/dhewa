import Foundation

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
}

