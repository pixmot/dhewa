import Foundation
import GRDB

public struct Budget: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    public static let databaseTableName = "budgets"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    public var householdId: String
    public var budgetMonth: Int32
    public var currencyCode: String
    public var amountMinor: Int64
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: String,
        householdId: String,
        budgetMonth: Int32,
        currencyCode: String,
        amountMinor: Int64,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.budgetMonth = budgetMonth
        self.currencyCode = currencyCode
        self.amountMinor = amountMinor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

public extension Budget {
    enum Columns: String, ColumnExpression {
        case id
        case householdId = "household_id"
        case budgetMonth = "budget_month"
        case currencyCode = "currency_code"
        case amountMinor = "amount_minor"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}
