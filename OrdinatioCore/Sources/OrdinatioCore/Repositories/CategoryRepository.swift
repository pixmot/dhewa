import Foundation
import GRDB

public enum CategoryRepository {
    public static func observeCategories(
        householdId: String,
        kind: CategoryKind? = nil
    ) -> ValueObservation<ValueReducers.Fetch<[Category]>> {
        ValueObservation.tracking { db in
            var request = Category
                .filter(Category.Columns.householdId == householdId)
                .filter(Category.Columns.deletedAt == nil)

            if let kind {
                request = request.filter(Category.Columns.kind == kind)
            }

            return try request
                .order(Category.Columns.kind.asc, Category.Columns.sortOrder.asc)
                .fetchAll(db)
        }
    }

    public static func createCategory(
        in db: Database,
        householdId: String,
        kind: CategoryKind,
        name: String,
        iconIndex: Int?
    ) throws -> Category {
        let now = Date()
        let maxSortOrder =
            try Int.fetchOne(
                db,
                sql:
                    "SELECT COALESCE(MAX(sort_order), -1) FROM categories WHERE household_id = ? AND kind = ? AND deleted_at IS NULL",
                arguments: [householdId, kind]
            ) ?? -1

        let category = Category(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            kind: kind,
            name: name,
            iconIndex: iconIndex,
            sortOrder: maxSortOrder + 1,
            createdAt: now,
            updatedAt: now
        )
        try category.insert(db)
        return category
    }

    public static func updateCategoryName(in db: Database, categoryId: String, name: String) throws {
        try db.execute(
            sql: "UPDATE categories SET name = ?, updated_at = ? WHERE id = ?",
            arguments: [name, Date(), categoryId]
        )
    }

    public static func deleteCategory(in db: Database, categoryId: String) throws {
        try db.execute(sql: "DELETE FROM categories WHERE id = ?", arguments: [categoryId])
    }

    public static func reorderCategories(in db: Database, householdId: String, orderedCategoryIds: [String]) throws {
        let now = Date()
        for (idx, id) in orderedCategoryIds.enumerated() {
            try db.execute(
                sql: "UPDATE categories SET sort_order = ?, updated_at = ? WHERE id = ? AND household_id = ?",
                arguments: [idx, now, id, householdId]
            )
        }
    }
}
