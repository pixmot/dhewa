import Foundation
import GRDB

public struct Budget: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    public static let databaseTableName = "budgets"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    public var householdId: String
    public var isOverall: Bool
    public var categoryId: String?
    public var timeFrameRaw: Int
    public var startDate: Date
    public var currencyCode: String
    public var amountMinor: Int64
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdId
        case isOverall
        case categoryId
        case timeFrameRaw = "timeFrame"
        case startDate
        case currencyCode
        case amountMinor
        case createdAt
        case updatedAt
        case deletedAt
    }

    public init(
        id: String,
        householdId: String,
        isOverall: Bool,
        categoryId: String?,
        timeFrameRaw: Int,
        startDate: Date,
        currencyCode: String,
        amountMinor: Int64,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.isOverall = isOverall
        self.categoryId = categoryId
        self.timeFrameRaw = timeFrameRaw
        self.startDate = startDate
        self.currencyCode = currencyCode
        self.amountMinor = amountMinor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

extension Budget {
    public enum Columns: String, ColumnExpression {
        case id
        case householdId = "household_id"
        case isOverall = "is_overall"
        case categoryId = "category_id"
        case timeFrameRaw = "time_frame"
        case startDate = "start_date"
        case currencyCode = "currency_code"
        case amountMinor = "amount_minor"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

extension Budget {
    public var timeFrame: BudgetTimeFrame {
        BudgetTimeFrame(rawValue: timeFrameRaw) ?? .month
    }
}
