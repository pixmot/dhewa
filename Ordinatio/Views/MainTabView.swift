import SwiftUI
import OrdinatioCore

struct MainTabView: View {
    let database: AppDatabase
    let householdId: String
    let defaultCurrencyCode: String

    @State private var selection: OrdinatioTab = .log
    @State private var lastNonAddSelection: OrdinatioTab = .log
    @State private var sheet: Sheet?

    enum Sheet: Identifiable {
        case addTransaction

        var id: String { "addTransaction" }
    }

    var body: some View {
        TabView(selection: $selection) {
            TransactionsView(
                database: database,
                householdId: householdId,
                defaultCurrencyCode: defaultCurrencyCode
            )
            .tag(OrdinatioTab.log)
            .tabItem { Label(OrdinatioTab.log.title, systemImage: OrdinatioTab.log.symbolName) }

            InsightsView()
                .tag(OrdinatioTab.insights)
                .tabItem { Label(OrdinatioTab.insights.title, systemImage: OrdinatioTab.insights.symbolName) }

            Color.clear
                .tag(OrdinatioTab.add)
                .tabItem { Label(OrdinatioTab.add.title, systemImage: OrdinatioTab.add.symbolName) }

            BudgetsView(
                database: database,
                householdId: householdId,
                defaultCurrencyCode: defaultCurrencyCode
            )
            .tag(OrdinatioTab.budgets)
            .tabItem { Label(OrdinatioTab.budgets.title, systemImage: OrdinatioTab.budgets.symbolName) }

            SettingsView(database: database, householdId: householdId)
                .tag(OrdinatioTab.settings)
                .tabItem { Label(OrdinatioTab.settings.title, systemImage: OrdinatioTab.settings.symbolName) }
        }
        .onChange(of: selection) { newValue in
            if newValue == .add {
                selection = lastNonAddSelection
                sheet = .addTransaction
            } else {
                lastNonAddSelection = newValue
            }
        }
        .fullScreenCover(item: $sheet) { sheet in
            switch sheet {
            case .addTransaction:
                TransactionEditorView(
                    database: database,
                    householdId: householdId,
                    defaultCurrencyCode: defaultCurrencyCode,
                    mode: .create
                )
            }
        }
        .ordinatioRoundedFontDesign()
    }
}
