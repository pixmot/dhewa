import Foundation
import GRDB

public struct Household: Codable, FetchableRecord, PersistableRecord, Identifiable, Hashable, Sendable {
    public static let databaseTableName = "households"
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public var id: String
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, name: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Household {
    public enum Columns: String, ColumnExpression {
        case id
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
