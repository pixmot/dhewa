import OrdinatioCore
import SwiftUI

struct TransactionsView: View {
    let db: DatabaseClient
    let householdId: String
    let defaultCurrencyCode: String

    @State private var viewModel: TransactionListViewModel

    @State private var showFilters = false
    @State private var editingRow: TransactionListRow?

    init(db: DatabaseClient, householdId: String, defaultCurrencyCode: String) {
        self.db = db
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        _viewModel = State(
            initialValue: TransactionListViewModel(
                db: db, householdId: householdId, defaultCurrencyCode: defaultCurrencyCode))
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

            Text(MoneyFormat.format(minorUnits: viewModel.netTotalMinor, currencyCode: viewModel.summaryCurrencyCode))
                .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(OrdinatioColor.textPrimary)

            HStack(spacing: 12) {
                Text(
                    "+\(MoneyFormat.format(minorUnits: viewModel.incomeTotalMinor, currencyCode: viewModel.summaryCurrencyCode))"
                )
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(OrdinatioColor.income)

                Text(
                    "-\(MoneyFormat.format(minorUnits: viewModel.expenseTotalAbsMinor, currencyCode: viewModel.summaryCurrencyCode))"
                )
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(OrdinatioColor.expense)
            }
        }
        .padding(.vertical, 10)
    }

    var body: some View {
        @Bindable var model = viewModel

        NavigationStack {
            List {
                summaryHeader
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 0, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)

                if model.sections.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "tray",
                        description: Text("Add your first transaction to get started.")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                ForEach(model.sections) { section in
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
            .searchable(text: $model.searchText, prompt: "Search notes")
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
                    categories: model.categories,
                    availableCurrencyCodes: model.availableCurrencyCodes,
                    defaultCurrencyCode: defaultCurrencyCode,
                    currentFilter: model.filter,
                    onApply: { model.filter = $0 }
                )
            }
            .sheet(item: $editingRow) { row in
                TransactionEditorView(
                    db: db,
                    householdId: householdId,
                    defaultCurrencyCode: defaultCurrencyCode,
                    mode: .edit(row)
                )
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: {
                        model.errorMessage != nil
                    },
                    set: { newValue in
                        if !newValue { model.errorMessage = nil }
                    })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }
}
