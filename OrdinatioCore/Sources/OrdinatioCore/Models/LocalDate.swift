import Foundation

public struct LocalDate: Hashable, Comparable, Codable, Sendable {
    public let yyyymmdd: Int32

    public init(yyyymmdd: Int32) {
        self.yyyymmdd = yyyymmdd
    }

    public init(year: Int, month: Int, day: Int) {
        precondition((1...9999).contains(year), "Invalid year")
        precondition((1...12).contains(month), "Invalid month")
        precondition((1...31).contains(day), "Invalid day")

        self.yyyymmdd = Int32(year * 10_000 + month * 100 + day)
    }

    public static func from(date: Date, calendar: Calendar = .current) -> LocalDate {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return LocalDate(
            year: components.year ?? 1,
            month: components.month ?? 1,
            day: components.day ?? 1
        )
    }

    public static func today(calendar: Calendar = .current) -> LocalDate {
        LocalDate.from(date: Date(), calendar: calendar)
    }

    public var year: Int { Int(yyyymmdd) / 10_000 }
    public var month: Int { (Int(yyyymmdd) / 100) % 100 }
    public var day: Int { Int(yyyymmdd) % 100 }

    public func date(calendar: Calendar = .current, timeZone: TimeZone = .current) -> Date {
        var calendar = calendar
        calendar.timeZone = timeZone
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    public func formatted(
        dateStyle: DateFormatter.Style = .medium,
        locale: Locale = .current,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateStyle = dateStyle
        formatter.timeStyle = .none
        return formatter.string(from: date(calendar: calendar, timeZone: timeZone))
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        lhs.yyyymmdd < rhs.yyyymmdd
    }
}
