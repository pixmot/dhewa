import Foundation
import GRDB

public enum SeedData {
    public static let defaultHouseholdName = "Household"

    public static let defaultExpenseCategoryNames: [String] = [
        "Groceries",
        "Dining",
        "Rent",
        "Utilities",
        "Transport",
        "Health",
        "Entertainment",
        "Shopping",
    ]

    public static let defaultIncomeCategoryNames: [String] = [
        "Income",
    ]

    public static func ensureDefaultHouseholdAndCategories(in db: Database) throws -> String {
        if let household = try Household.fetchOne(db) {
            return household.id
        }

        let now = Date()
        let householdId = UUID().uuidString.lowercased()
        let household = Household(id: householdId, name: defaultHouseholdName, createdAt: now, updatedAt: now)
        try household.insert(db)

        for (idx, name) in defaultExpenseCategoryNames.enumerated() {
            let category = Category(
                id: UUID().uuidString.lowercased(),
                householdId: householdId,
                kind: .expense,
                name: name,
                sortOrder: idx,
                createdAt: now,
                updatedAt: now
            )
            try category.insert(db)
        }

        for (idx, name) in defaultIncomeCategoryNames.enumerated() {
            let category = Category(
                id: UUID().uuidString.lowercased(),
                householdId: householdId,
                kind: .income,
                name: name,
                sortOrder: idx,
                createdAt: now,
                updatedAt: now
            )
            try category.insert(db)
        }

        return householdId
    }
}
