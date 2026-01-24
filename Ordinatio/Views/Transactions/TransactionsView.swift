import SwiftUI
import OrdinatioCore

struct TransactionsView: View {
    let database: AppDatabase
    let householdId: String
    let defaultCurrencyCode: String

    @StateObject private var viewModel: TransactionListViewModel

    @State private var showFilters = false
    @State private var editingRow: TransactionListRow?

    init(database: AppDatabase, householdId: String, defaultCurrencyCode: String) {
        self.database = database
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        _viewModel = StateObject(wrappedValue: TransactionListViewModel(database: database, householdId: householdId))
    }

    private var summaryCurrencyCode: String {
        if let code = viewModel.filter.currencyCode, !code.isEmpty {
            return code.uppercased()
        }
        return defaultCurrencyCode.uppercased()
    }

    private var filteredSummaryRows: [TransactionListRow] {
        viewModel.sections.flatMap(\.rows).filter { $0.currencyCode.uppercased() == summaryCurrencyCode }
    }

    private var netTotalMinor: Int64 {
        filteredSummaryRows.reduce(0) { $0 + $1.amountMinor }
    }

    private var incomeTotalMinor: Int64 {
        filteredSummaryRows.reduce(0) { $1.amountMinor > 0 ? $0 + $1.amountMinor : $0 }
    }

    private var expenseTotalAbsMinor: Int64 {
        filteredSummaryRows.reduce(0) { $1.amountMinor < 0 ? $0 + abs($1.amountMinor) : $0 }
    }

    private func sectionTitle(for date: LocalDate) -> String {
        let calendar = Calendar.current
        let value = date.date(calendar: calendar)
        if calendar.isDateInToday(value) { return "Today" }
        if calendar.isDateInYesterday(value) { return "Yesterday" }
        return date.formatted(dateStyle: .medium)
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Net total · this week")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OrdinatioColor.textSecondary)

            Text(MoneyFormat.format(minorUnits: netTotalMinor, currencyCode: summaryCurrencyCode))
                .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(OrdinatioColor.textPrimary)

            HStack(spacing: 12) {
                Text("+\(MoneyFormat.format(minorUnits: incomeTotalMinor, currencyCode: summaryCurrencyCode))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(OrdinatioColor.income)

                Text("-\(MoneyFormat.format(minorUnits: expenseTotalAbsMinor, currencyCode: summaryCurrencyCode))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(OrdinatioColor.expense)
            }
        }
        .padding(.vertical, 10)
    }

    var body: some View {
        NavigationStack {
            List {
                summaryHeader
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 0, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)

                if viewModel.sections.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "tray",
                        description: Text("Add your first transaction to get started.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                ForEach(viewModel.sections) { section in
                    Section {
                        ForEach(section.rows) { row in
                            TransactionRowView(row: row)
                                .contentShape(Rectangle())
                                .onTapGesture { editingRow = row }
                                .listRowSeparator(.hidden)
                                .listRowBackground(OrdinatioColor.background)
                        }
                    } header: {
                        Text(sectionTitle(for: section.date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                            .textCase(.uppercase)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(OrdinatioColor.background)
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filters")
                }
            }
            .sheet(isPresented: $showFilters) {
                TransactionFiltersView(
                    categories: viewModel.categories,
                    availableCurrencyCodes: viewModel.availableCurrencyCodes,
                    defaultCurrencyCode: defaultCurrencyCode,
                    currentFilter: viewModel.filter,
                    onApply: { viewModel.filter = $0 }
                )
            }
            .sheet(item: $editingRow) { row in
                TransactionEditorView(
                    database: database,
                    householdId: householdId,
                    defaultCurrencyCode: defaultCurrencyCode,
                    mode: .edit(row)
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
