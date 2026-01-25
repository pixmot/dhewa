import Foundation
import GRDB

public final class AppDatabase {
    public let dbQueue: DatabaseQueue

    public init(databaseURL: URL) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        self.dbQueue = try DatabaseQueue(path: databaseURL.path, configuration: configuration)
        try Self.makeMigrator().migrate(dbQueue)
    }

    public static func inMemory() throws -> AppDatabase {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let dbQueue = try DatabaseQueue(path: ":memory:", configuration: configuration)
        try makeMigrator().migrate(dbQueue)
        return try AppDatabase(dbQueue: dbQueue)
    }

    private init(dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
    }

    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        try dbQueue.read(block)
    }

    public func write<T>(_ block: (Database) throws -> T) throws -> T {
        try dbQueue.write(block)
    }

    public func resetAllData() throws {
        try write { db in
            try db.execute(sql: "DELETE FROM transactions")
            try db.execute(sql: "DELETE FROM budgets")
            try db.execute(sql: "DELETE FROM categories")
            try db.execute(sql: "DELETE FROM households")
        }
    }

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_tables") { db in
            try db.create(table: "households") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            try db.create(table: "categories") { t in
                t.column("id", .text).primaryKey()
                t.column("household_id", .text)
                    .notNull()
                    .indexed()
                    .references("households", onDelete: .cascade, onUpdate: .cascade)
                t.column("name", .text).notNull()
                t.column("sort_order", .integer).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }
            try db.create(
                index: "idx_categories_household_sort", on: "categories", columns: ["household_id", "sort_order"])

            try db.create(table: "transactions") { t in
                t.column("id", .text).primaryKey()
                t.column("household_id", .text)
                    .notNull()
                    .indexed()
                    .references("households", onDelete: .cascade, onUpdate: .cascade)
                t.column("category_id", .text)
                    .references("categories", onDelete: .setNull, onUpdate: .cascade)
                t.column("amount_minor", .integer).notNull()
                t.column("currency_code", .text).notNull()
                t.column("txn_date", .integer).notNull()
                t.column("note", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }
            try db.create(
                index: "idx_transactions_household_date", on: "transactions", columns: ["household_id", "txn_date"])
            try db.create(
                index: "idx_transactions_category_date", on: "transactions", columns: ["category_id", "txn_date"])
            try db.create(index: "idx_transactions_updated_at", on: "transactions", columns: ["updated_at"])

            try db.create(table: "budgets") { t in
                t.column("id", .text).primaryKey()
                t.column("household_id", .text)
                    .notNull()
                    .indexed()
                    .references("households", onDelete: .cascade, onUpdate: .cascade)
                t.column("budget_month", .integer).notNull()
                t.column("currency_code", .text).notNull()
                t.column("amount_minor", .integer).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)

                t.uniqueKey(["household_id", "budget_month", "currency_code"])
            }
            try db.create(
                index: "idx_budgets_household_month", on: "budgets", columns: ["household_id", "budget_month"])
        }

        migrator.registerMigration("v2_rebuild_budgets") { db in
            try db.execute(sql: "DROP TABLE IF EXISTS budgets")

            try db.create(table: "budgets") { t in
                t.column("id", .text).primaryKey()
                t.column("household_id", .text)
                    .notNull()
                    .indexed()
                    .references("households", onDelete: .cascade, onUpdate: .cascade)
                t.column("is_overall", .boolean).notNull()
                t.column("category_id", .text)
                    .references("categories", onDelete: .cascade, onUpdate: .cascade)
                t.column("time_frame", .integer).notNull()
                t.column("start_date", .datetime).notNull()
                t.column("currency_code", .text).notNull()
                t.column("amount_minor", .integer).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }

            try db.execute(sql: "CREATE UNIQUE INDEX idx_budgets_overall ON budgets(household_id) WHERE is_overall = 1")
            try db.execute(
                sql:
                    "CREATE UNIQUE INDEX idx_budgets_category ON budgets(household_id, category_id) WHERE is_overall = 0"
            )
            try db.create(
                index: "idx_budgets_household_timeframe", on: "budgets", columns: ["household_id", "time_frame"])
        }

        migrator.registerMigration("v3_add_category_icon_index") { db in
            try db.alter(table: "categories") { t in
                t.add(column: "icon_index", .integer)
            }
        }

        migrator.registerMigration("v4_add_category_kind") { db in
            try db.execute(sql: "ALTER TABLE categories ADD COLUMN kind INTEGER NOT NULL DEFAULT 0")

            // Best-effort backfill for the seeded "Income" category name.
            try db.execute(sql: "UPDATE categories SET kind = 1 WHERE lower(name) = 'income'")

            try db.execute(
                sql: "CREATE INDEX IF NOT EXISTS idx_categories_household_kind_sort ON categories(household_id, kind, sort_order)"
            )
        }

        return migrator
    }
}
