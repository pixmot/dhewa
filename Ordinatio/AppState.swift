import Foundation
import OrdinatioCore

@MainActor
final class AppState: ObservableObject {
    let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func ensureSeedData() throws -> String {
        try database.write { db in
            try SeedData.ensureDefaultHouseholdAndCategories(in: db)
        }
    }

    func resetAllData() throws {
        try database.resetAllData()
    }
}

