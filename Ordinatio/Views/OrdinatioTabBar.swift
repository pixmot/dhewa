import SwiftUI

enum OrdinatioTab: Hashable {
    case log
    case insights
    case add
    case budgets

    var title: String {
        switch self {
        case .log: return "Log"
        case .insights: return "Insights"
        case .add: return "Add"
        case .budgets: return "Budgets"
        }
    }

    var symbolName: String {
        switch self {
        case .log: return "list.bullet"
        case .insights: return "chart.bar.xaxis"
        case .add: return "plus"
        case .budgets: return "square.grid.2x2"
        }
    }
}

