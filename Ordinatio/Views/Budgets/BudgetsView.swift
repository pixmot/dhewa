import SwiftUI
import OrdinatioCore

struct BudgetsView: View {
    let database: AppDatabase
    let householdId: String
    let defaultCurrencyCode: String

    @StateObject private var viewModel: BudgetsViewModel
    @State private var showCreate = false
    @State private var editingSummary: CurrencyBudgetSummary?

    init(database: AppDatabase, householdId: String, defaultCurrencyCode: String) {
        self.database = database
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        _viewModel = StateObject(wrappedValue: BudgetsViewModel(database: database, householdId: householdId))
    }

    private func progress(spent: Int64, budget: Int64?) -> Double? {
        guard let budget, budget > 0 else { return nil }
        return min(Double(spent) / Double(budget), 1.0)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Button { viewModel.previousMonth() } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.plain)

                        Spacer()
                        Text(viewModel.month.formatted())
                            .font(.headline)
                            .foregroundStyle(OrdinatioColor.textPrimary)
                        Spacer()

                        Button { viewModel.nextMonth() } label: {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(OrdinatioColor.background)

                if viewModel.summaries.isEmpty {
                    Group {
                        if #available(iOS 17.0, *) {
                            ContentUnavailableView(
                                "No Budgets",
                                systemImage: "chart.pie",
                                description: Text("Set a monthly budget per currency.")
                            )
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "chart.pie")
                                    .font(.system(size: 40, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text("No Budgets")
                                    .font(.title2.weight(.semibold))
                                Text("Set a monthly budget per currency.")
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section("This Month") {
                    ForEach(viewModel.summaries, id: \.currencyCode) { summary in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(summary.currencyCode)
                                    .font(.headline)
                                    .foregroundStyle(OrdinatioColor.textPrimary)
                                Spacer()
                                if let budgetMinor = summary.budgetMinor {
                                    Text("\(MoneyFormat.format(minorUnits: summary.spentAbsMinor, currencyCode: summary.currencyCode)) / \(MoneyFormat.format(minorUnits: budgetMinor, currencyCode: summary.currencyCode))")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(OrdinatioColor.textSecondary)
                                } else {
                                    Text(MoneyFormat.format(minorUnits: summary.spentAbsMinor, currencyCode: summary.currencyCode))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(OrdinatioColor.textSecondary)
                                }
                            }

                            if let p = progress(spent: summary.spentAbsMinor, budget: summary.budgetMinor) {
                                ProgressView(value: p)
                            }
                        }
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: OrdinatioMetric.cardCornerRadius, style: .continuous)
                                .fill(OrdinatioColor.surface)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: OrdinatioMetric.cardCornerRadius, style: .continuous)
                                .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingSummary = summary }
                        .listRowSeparator(.hidden)
                        .listRowBackground(OrdinatioColor.background)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(OrdinatioColor.background)
            .navigationTitle("Budgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Budget")
                }
            }
            .sheet(isPresented: $showCreate) {
                BudgetEditorView(
                    mode: .create(month: viewModel.month, defaultCurrencyCode: defaultCurrencyCode),
                    onSave: { code, amountMinor in
                        viewModel.upsertBudget(currencyCode: code, amountMinor: amountMinor)
                    }
                )
            }
            .sheet(item: $editingSummary) { summary in
                BudgetEditorView(
                    mode: .edit(month: viewModel.month, summary: summary),
                    onSave: { code, amountMinor in
                        viewModel.upsertBudget(currencyCode: code, amountMinor: amountMinor)
                    },
                    onDelete: { code in
                        viewModel.deleteBudget(currencyCode: code)
                    }
                )
            }
            .alert("Error", isPresented: Binding(get: {
                viewModel.errorMessage != nil
            }, set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
