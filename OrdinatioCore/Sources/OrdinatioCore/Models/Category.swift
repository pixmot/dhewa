import Foundation
import GRDB

public struct Category: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    public static let databaseTableName = "categories"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    public var householdId: String
    public var kind: CategoryKind
    public var name: String
    public var iconIndex: Int?
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: String,
        householdId: String,
        kind: CategoryKind,
        name: String,
        iconIndex: Int? = nil,
        sortOrder: Int,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.kind = kind
        self.name = name
        self.iconIndex = iconIndex
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

extension Category {
    public enum Columns: String, ColumnExpression {
        case id
        case householdId = "household_id"
        case kind
        case name
        case iconIndex = "icon_index"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}
