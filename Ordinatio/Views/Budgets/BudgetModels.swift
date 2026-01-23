import Foundation
import OrdinatioCore

struct BudgetSnapshot: Identifiable, Hashable {
    let budget: Budget
    let category: OrdinatioCore.Category?
    let period: BudgetPeriod
    let spentAbsMinor: Int64

    var id: String { budget.id }
}

struct BudgetPeriod: Hashable {
    let timeFrame: BudgetTimeFrame
    let start: Date
    let end: Date

    func progress(at date: Date = Date(), calendar: Calendar = .current) -> Double {
        let clamped = min(max(date, start), end)
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(max(clamped.timeIntervalSince(start) / total, 0), 1)
    }

    func daysLeft(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        let total = max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
        let elapsed = max(calendar.dateComponents([.day], from: start, to: date).day ?? 0, 0)
        return max(total - elapsed, 0)
    }

    func hoursLeft(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        let total = max(calendar.dateComponents([.hour], from: start, to: end).hour ?? 0, 0)
        let elapsed = max(calendar.dateComponents([.hour], from: start, to: date).hour ?? 0, 0)
        return max(total - elapsed, 0)
    }

    func remainingFractionForBarMarker(at date: Date = Date(), calendar: Calendar = .current) -> Double {
        let totalDays = max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
        guard totalDays > 0 else { return 0 }
        let daysElapsed = max(calendar.dateComponents([.day], from: start, to: date).day ?? 0, 0)
        return min(max(Double(totalDays - daysElapsed) / Double(totalDays), 0), 1)
    }

    func remainingFractionForGaugeMarker(at date: Date = Date(), calendar: Calendar = .current) -> Double {
        let totalDays = max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
        guard totalDays > 0 else { return 0 }
        let daysElapsed = max(calendar.dateComponents([.day], from: start, to: date).day ?? 0, 0)
        return min(max(Double(totalDays - (daysElapsed + 1)) / Double(totalDays), 0), 1)
    }
}

enum BudgetDateHelper {
    static func normalizedStartDate(
        for budget: Budget,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let reference = calendar.startOfDay(for: referenceDate)
        let anchor = calendar.startOfDay(for: budget.startDate)

        switch budget.timeFrame {
        case .day:
            return reference
        case .week:
            let weekday = calendar.component(.weekday, from: anchor)
            let match = calendar.nextDate(
                after: reference,
                matching: DateComponents(weekday: weekday),
                matchingPolicy: .nextTime,
                direction: .backward
            )
            return calendar.startOfDay(for: match ?? anchor)
        case .month:
            let anchorDay = calendar.component(.day, from: anchor)
            return normalizedMonthlyStart(anchorDay: anchorDay, reference: reference, calendar: calendar)
        case .year:
            let anchorMonth = calendar.component(.month, from: anchor)
            let anchorDay = calendar.component(.day, from: anchor)
            return normalizedYearlyStart(anchorMonth: anchorMonth, anchorDay: anchorDay, reference: reference, calendar: calendar)
        }
    }

    static func period(for budget: Budget, referenceDate: Date = Date(), calendar: Calendar = .current) -> BudgetPeriod {
        let start = normalizedStartDate(for: budget, referenceDate: referenceDate, calendar: calendar)
        let end = endDate(for: budget.timeFrame, startDate: start, calendar: calendar)
        return BudgetPeriod(timeFrame: budget.timeFrame, start: start, end: end)
    }

    static func period(for timeFrame: BudgetTimeFrame, startDate: Date, calendar: Calendar = .current) -> BudgetPeriod {
        let start = calendar.startOfDay(for: startDate)
        let end = endDate(for: timeFrame, startDate: start, calendar: calendar)
        return BudgetPeriod(timeFrame: timeFrame, start: start, end: end)
    }

    static func endDate(for timeFrame: BudgetTimeFrame, startDate: Date, calendar: Calendar = .current) -> Date {
        switch timeFrame {
        case .day:
            return calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case .week:
            return calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate
        case .month:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .year:
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        }
    }

    private static func normalizedMonthlyStart(
        anchorDay: Int,
        reference: Date,
        calendar: Calendar
    ) -> Date {
        let components = calendar.dateComponents([.year, .month], from: reference)
        let currentStart = clampedDate(
            year: components.year ?? 1,
            month: components.month ?? 1,
            day: anchorDay,
            calendar: calendar
        )
        if currentStart <= reference {
            return currentStart
        }
        let previous = calendar.date(byAdding: .month, value: -1, to: currentStart) ?? currentStart
        let prevComponents = calendar.dateComponents([.year, .month], from: previous)
        return clampedDate(
            year: prevComponents.year ?? 1,
            month: prevComponents.month ?? 1,
            day: anchorDay,
            calendar: calendar
        )
    }

    private static func normalizedYearlyStart(
        anchorMonth: Int,
        anchorDay: Int,
        reference: Date,
        calendar: Calendar
    ) -> Date {
        let year = calendar.component(.year, from: reference)
        let currentStart = clampedDate(
            year: year,
            month: anchorMonth,
            day: anchorDay,
            calendar: calendar
        )
        if currentStart <= reference {
            return currentStart
        }
        return clampedDate(
            year: year - 1,
            month: anchorMonth,
            day: anchorDay,
            calendar: calendar
        )
    }

    private static func clampedDate(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar
    ) -> Date {
        let safeMonth = min(max(month, 1), 12)
        let base = calendar.date(from: DateComponents(year: year, month: safeMonth, day: 1)) ?? Date()
        let dayRange = calendar.range(of: .day, in: .month, for: base) ?? 1..<2
        let safeDay = min(max(day, 1), dayRange.count)
        return calendar.date(from: DateComponents(year: year, month: safeMonth, day: safeDay)) ?? base
    }
}
