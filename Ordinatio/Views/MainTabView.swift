import SwiftUI
import OrdinatioCore

struct MainTabView: View {
    let database: AppDatabase
    let householdId: String
    let defaultCurrencyCode: String

    @State private var selection: OrdinatioTab = .log
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

            InsightsView()
                .tag(OrdinatioTab.insights)

            BudgetsView(
                database: database,
                householdId: householdId,
                defaultCurrencyCode: defaultCurrencyCode
            )
            .tag(OrdinatioTab.budgets)

            SettingsView(database: database, householdId: householdId)
                .tag(OrdinatioTab.settings)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            OrdinatioTabBar(selection: $selection) {
                sheet = .addTransaction
            }
            .padding(.horizontal, OrdinatioMetric.tabBarHorizontalPadding)
            .padding(.bottom, 8)
            .padding(.top, 6)
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
