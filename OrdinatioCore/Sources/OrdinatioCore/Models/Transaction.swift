import Foundation
import GRDB

public struct Transaction: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    public static let databaseTableName = "transactions"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    public var householdId: String
    public var categoryId: String?
    public var amountMinor: Int64
    public var currencyCode: String
    public var txnDate: Int32
    public var note: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: String,
        householdId: String,
        categoryId: String?,
        amountMinor: Int64,
        currencyCode: String,
        txnDate: Int32,
        note: String?,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.categoryId = categoryId
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.txnDate = txnDate
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

extension Transaction {
    public enum Columns: String, ColumnExpression {
        case id
        case householdId = "household_id"
        case categoryId = "category_id"
        case amountMinor = "amount_minor"
        case currencyCode = "currency_code"
        case txnDate = "txn_date"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

public struct TransactionListRow: FetchableRecord, Decodable, Hashable, Sendable {
    public var id: String
    public var householdId: String
    public var categoryId: String?
    public var categoryName: String?
    public var categoryIconIndex: Int?
    public var amountMinor: Int64
    public var currencyCode: String
    public var txnDate: Int32
    public var note: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String,
        householdId: String,
        categoryId: String?,
        categoryName: String?,
        categoryIconIndex: Int?,
        amountMinor: Int64,
        currencyCode: String,
        txnDate: Int32,
        note: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.householdId = householdId
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.categoryIconIndex = categoryIconIndex
        self.amountMinor = amountMinor
        self.currencyCode = currencyCode
        self.txnDate = txnDate
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct TransactionFilter: Hashable, Sendable {
    public var categoryId: String?
    public var currencyCode: String?
    public var minAbsAmountMinor: Int64?
    public var maxAbsAmountMinor: Int64?
    public var searchText: String

    public init(
        categoryId: String? = nil,
        currencyCode: String? = nil,
        minAbsAmountMinor: Int64? = nil,
        maxAbsAmountMinor: Int64? = nil,
        searchText: String = ""
    ) {
        self.categoryId = categoryId
        self.currencyCode = currencyCode
        self.minAbsAmountMinor = minAbsAmountMinor
        self.maxAbsAmountMinor = maxAbsAmountMinor
        self.searchText = searchText
    }
}
