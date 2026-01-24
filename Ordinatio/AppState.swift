import Foundation
import Observation
import OrdinatioCore

@MainActor
@Observable
final class AppState {
    let db: DatabaseClient

    init(database: AppDatabase) {
        self.db = DatabaseClient(database: database)
    }

    func ensureSeedData() async throws -> String {
        try await db.ensureSeedData()
    }
}
