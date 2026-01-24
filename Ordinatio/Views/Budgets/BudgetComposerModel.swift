import Foundation
import Observation
import OrdinatioCore
import SwiftUI

@MainActor
@Observable
final class BudgetComposerModel {
    var categories: [OrdinatioCore.Category]
    let existingCategoryBudgetIds: Set<String>
    let defaultCurrencyCode: String

    var progress: Int
    let initialProgress: Int

    var categoryBudget: Bool
    var selectedCategoryId: String?

    var budgetTimeFrame: BudgetTimeFrame
    var chosenDayWeek: Int
    var chosenDayMonth: Int
    var chosenDayYear: Date

    var amountMinor: Int64

    var showToast = false
    var toastMessage = "Missing Category"
    var showingCategoryCreator = false

    var sensoryFeedbackTrigger = 0
    var pendingSensoryFeedback: SensoryFeedback?

    init(
        route: BudgetComposerRoute,
        categories: [OrdinatioCore.Category],
        existingCategoryBudgetIds: Set<String>,
        defaultCurrencyCode: String
    ) {
        self.categories = categories
        self.existingCategoryBudgetIds = existingCategoryBudgetIds
        self.defaultCurrencyCode = defaultCurrencyCode

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let initialProgress = route.overallExists ? 2 : 1
        self.initialProgress = initialProgress
        self.progress = initialProgress
        self.categoryBudget = route.overallExists ? true : false
        self.selectedCategoryId = nil
        self.budgetTimeFrame = .week
        self.chosenDayWeek = calendar.component(.weekday, from: today)
        self.chosenDayMonth = 1
        self.chosenDayYear = today
        self.amountMinor = 0
    }
}
