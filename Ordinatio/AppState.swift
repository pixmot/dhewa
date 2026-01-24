import Foundation
import Observation
import OrdinatioCore

@MainActor
@Observable
final class AppState {
    let database: AppDatabase
    let db: DatabaseClient

    init(database: AppDatabase) {
        self.database = database
        self.db = DatabaseClient(database: database)
    }

    func ensureSeedData() async throws -> String {
        try await db.ensureSeedData()
    }
}
