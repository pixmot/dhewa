import Foundation

public struct YearMonth: Hashable, Comparable, Codable, Sendable {
    public let yyyymm: Int32

    public init(yyyymm: Int32) {
        self.yyyymm = yyyymm
    }

    public init(year: Int, month: Int) {
        precondition((1...9999).contains(year), "Invalid year")
        precondition((1...12).contains(month), "Invalid month")
        self.yyyymm = Int32(year * 100 + month)
    }

    public static func current(calendar: Calendar = .current) -> YearMonth {
        let components = calendar.dateComponents([.year, .month], from: Date())
        return YearMonth(year: components.year ?? 1, month: components.month ?? 1)
    }

    public var year: Int { Int(yyyymm) / 100 }
    public var month: Int { Int(yyyymm) % 100 }

    public func startDate(calendar: Calendar = .current, timeZone: TimeZone = .current) -> Date {
        var calendar = calendar
        calendar.timeZone = timeZone
        let components = DateComponents(year: year, month: month, day: 1)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    public func next(calendar: Calendar = .current) -> YearMonth {
        var nextYear = year
        var nextMonth = month + 1
        if nextMonth == 13 {
            nextMonth = 1
            nextYear += 1
        }
        return YearMonth(year: nextYear, month: nextMonth)
    }

    public func formatted(locale: Locale = .current, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: startDate(calendar: calendar))
    }

    public static func < (lhs: YearMonth, rhs: YearMonth) -> Bool {
        lhs.yyyymm < rhs.yyyymm
    }
}
