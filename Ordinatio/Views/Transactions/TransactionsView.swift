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

    private var trendLineColor: Color {
        if viewModel.netTotalMinor > 0 { return OrdinatioColor.income }
        if viewModel.netTotalMinor < 0 { return OrdinatioColor.expense }
        return OrdinatioColor.textSecondary
    }

    private func dayTotalText(for section: TransactionSection) -> String {
        guard let netTotalMinor = section.netTotalMinor else { return "—" }
        let formatted = MoneyFormat.format(
            minorUnits: abs(netTotalMinor),
            currencyCode: viewModel.summaryCurrencyCode
        )
        if netTotalMinor > 0 { return "+\(formatted)" }
        if netTotalMinor < 0 { return "-\(formatted)" }
        return formatted
    }

    private func dayTotalColor(for section: TransactionSection) -> Color {
        guard let netTotalMinor = section.netTotalMinor else { return OrdinatioColor.textSecondary }
        if netTotalMinor > 0 { return OrdinatioColor.income }
        if netTotalMinor < 0 { return OrdinatioColor.expense }
        return OrdinatioColor.textSecondary
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Net total")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textSecondary)

                Text("All time")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background {
                        Capsule(style: .continuous)
                            .fill(OrdinatioColor.surfaceElevated)
                    }
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
                    }
            }

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

            MiniTrendChart(values: viewModel.sparklineValues, lineColor: trendLineColor)
                .accessibilityLabel("Net total trend")
        }
        .padding(.vertical, 8)
    }

    var body: some View {
        @Bindable var model = viewModel

        NavigationStack {
            List {
                summaryHeader
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 0, leading: 16, bottom: 12, trailing: 16))
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
                        HStack {
                            Text(sectionTitle(for: section.date))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(OrdinatioColor.textSecondary)
                                .textCase(.uppercase)

                            Spacer()

                            Text(dayTotalText(for: section))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(dayTotalColor(for: section))
                        }
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

private struct MiniTrendChart: View {
    let values: [Int64]
    let lineColor: Color
    var baselineColor: Color = OrdinatioColor.separator.opacity(0.6)

    var body: some View {
        GeometryReader { proxy in
            let layout = sparklineLayout(in: proxy.size)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: layout.baselineY))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: layout.baselineY))
                }
                .stroke(baselineColor, lineWidth: 1)

                if layout.points.count > 1 {
                    Path { path in
                        guard let first = layout.points.first else { return }
                        path.move(to: first)
                        for point in layout.points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                } else if let point = layout.points.first {
                    Circle()
                        .fill(lineColor)
                        .frame(width: 4, height: 4)
                        .position(point)
                }
            }
        }
        .frame(height: 48)
    }

    private func sparklineLayout(in size: CGSize) -> (points: [CGPoint], baselineY: CGFloat) {
        guard !values.isEmpty else {
            return ([], size.height * 0.7)
        }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let range = maxValue - minValue
        let verticalPadding = size.height * 0.2
        let drawableHeight = max(size.height - verticalPadding * 2, 1)

        func yPosition(for value: Int64) -> CGFloat {
            let normalized: CGFloat
            if range == 0 {
                normalized = 0.5
            } else {
                normalized = CGFloat(value - minValue) / CGFloat(range)
            }
            return size.height - verticalPadding - normalized * drawableHeight
        }

        if values.count == 1 {
            let point = CGPoint(x: size.width * 0.5, y: yPosition(for: values[0]))
            let baselineY = range == 0 ? point.y : size.height - verticalPadding
            return ([point], baselineY)
        }

        let stepX = size.width / CGFloat(max(values.count - 1, 1))
        let points = values.enumerated().map { index, value in
            CGPoint(x: CGFloat(index) * stepX, y: yPosition(for: value))
        }
        let baselineY = range == 0 ? points.first?.y ?? size.height * 0.5 : size.height - verticalPadding
        return (points, baselineY)
    }
}
