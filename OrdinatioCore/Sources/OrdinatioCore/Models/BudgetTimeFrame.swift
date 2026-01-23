import Foundation

public enum BudgetTimeFrame: Int, Codable, CaseIterable, Sendable {
    case day = 1
    case week = 2
    case month = 3
    case year = 4

    public var title: String {
        switch self {
        case .day: return "Daily"
        case .week: return "Weekly"
        case .month: return "Monthly"
        case .year: return "Yearly"
        }
    }

    public var periodLabel: String {
        switch self {
        case .day: return "today"
        case .week: return "this week"
        case .month: return "this month"
        case .year: return "this year"
        }
    }
}
