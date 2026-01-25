import GRDB

public enum CategoryKind: Int, Codable, CaseIterable, Sendable {
    case expense = 0
    case income = 1
}

extension CategoryKind: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        rawValue.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CategoryKind? {
        guard let rawValue = Int.fromDatabaseValue(dbValue) else { return nil }
        return CategoryKind(rawValue: rawValue)
    }
}

