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
        var style = Date.FormatStyle(date: formatStyle(for: dateStyle), time: .omitted)
        style.locale = locale
        style.calendar = calendar
        style.timeZone = timeZone

        return date(calendar: calendar, timeZone: timeZone).formatted(style)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        lhs.yyyymmdd < rhs.yyyymmdd
    }

    private func formatStyle(for dateStyle: DateFormatter.Style) -> Date.FormatStyle.DateStyle {
        switch dateStyle {
        case .none:
            return .omitted
        case .short:
            return .numeric
        case .medium:
            return .abbreviated
        case .long:
            return .long
        case .full:
            return .complete
        @unknown default:
            return .abbreviated
        }
    }
}
