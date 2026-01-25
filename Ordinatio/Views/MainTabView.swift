import OrdinatioCore
import SwiftUI

struct MainTabView: View {
    let db: DatabaseClient
    let householdId: String
    let defaultCurrencyCode: String

    @State private var selection: OrdinatioTab = .log

    var body: some View {
        TabView(selection: $selection) {
            TransactionsView(
                db: db,
                householdId: householdId,
                defaultCurrencyCode: defaultCurrencyCode
            )
            .tag(OrdinatioTab.log)
            .tabItem { Label(OrdinatioTab.log.title, systemImage: OrdinatioTab.log.symbolName) }

            InsightsView()
                .tag(OrdinatioTab.insights)
                .tabItem { Label(OrdinatioTab.insights.title, systemImage: OrdinatioTab.insights.symbolName) }

            TransactionEditorView(
                db: db,
                householdId: householdId,
                defaultCurrencyCode: defaultCurrencyCode,
                mode: .create,
                showsDismissButton: false,
                onSave: { selection = .log }
            )
            .tag(OrdinatioTab.add)
            .tabItem { Label(OrdinatioTab.add.title, systemImage: OrdinatioTab.add.symbolName) }

            BudgetsView(
                db: db,
                householdId: householdId,
                defaultCurrencyCode: defaultCurrencyCode
            )
            .tag(OrdinatioTab.budgets)
            .tabItem { Label(OrdinatioTab.budgets.title, systemImage: OrdinatioTab.budgets.symbolName) }
        }
        .fontDesign(.rounded)
    }
}
