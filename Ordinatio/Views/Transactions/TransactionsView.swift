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
        guard let netTotalMinor = viewModel.netTotalMinor else { return OrdinatioColor.textSecondary }
        if netTotalMinor > 0 { return OrdinatioColor.income }
        if netTotalMinor < 0 { return OrdinatioColor.expense }
        return OrdinatioColor.textSecondary
    }

    private func dayTotal(for section: TransactionSection) -> (text: String, color: Color)? {
        guard let currencyCode = viewModel.summaryCurrencyCode else { return nil }
        guard let netTotalMinor = section.netTotalMinor else { return nil }
        let formatted = MoneyFormat.format(minorUnits: netTotalMinor.ordinatioSafeAbs, currencyCode: currencyCode)
        if netTotalMinor > 0 { return ("+\(formatted)", OrdinatioColor.income) }
        if netTotalMinor < 0 { return ("-\(formatted)", OrdinatioColor.expense) }
        return (formatted, OrdinatioColor.textSecondary)
    }

    private func dayHeader(for section: TransactionSection) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(sectionTitle(for: section.date))
                    .textCase(.uppercase)

                Spacer()

                if let total = dayTotal(for: section) {
                    Text(total.text)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(total.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(OrdinatioColor.textSecondary)
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(OrdinatioColor.separator.opacity(0.7))
                .frame(height: 1)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var currencySummaryText: String {
        let codes = viewModel.availableCurrencyCodes
        guard !codes.isEmpty else { return "No transactions yet" }

        if codes.count <= 3 {
            return codes.joined(separator: " · ")
        }
        let head = codes.prefix(3).joined(separator: " · ")
        return "\(head) +\(codes.count - 3)"
    }

    private var summaryHeader: some View {
        VStack(spacing: 6) {
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Text("Net total")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textSecondary)

                    Text("All time")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background {
                            Capsule(style: .continuous)
                                .fill(OrdinatioColor.surfaceElevated)
                        }
                        .overlay {
                            Capsule(style: .continuous)
                                .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
                        }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                if let currencyCode = viewModel.summaryCurrencyCode, let netTotalMinor = viewModel.netTotalMinor {
                    SummaryAmountText(valueMinor: netTotalMinor, currencyCode: currencyCode)
                        .accessibilityLabel(
                            MoneyFormat.format(minorUnits: netTotalMinor, currencyCode: currencyCode)
                        )

                    if let income = viewModel.incomeTotalMinor, let expenseAbs = viewModel.expenseTotalAbsMinor {
                        HStack(spacing: 12) {
                            MiniSignedAmountText(
                                sign: "+",
                                absMinor: income,
                                currencyCode: currencyCode,
                                tint: OrdinatioColor.income
                            )

                            MiniSignedAmountText(
                                sign: "-",
                                absMinor: expenseAbs,
                                currencyCode: currencyCode,
                                tint: OrdinatioColor.expense
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityElement(children: .combine)
                    }
                } else if viewModel.availableCurrencyCodes.count > 1 {
                    Text("Multiple currencies")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(currencySummaryText)
                        .font(.caption)
                        .foregroundStyle(OrdinatioColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("—")
                        .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(OrdinatioColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity, alignment: .center)

            if !viewModel.sparklineValues.isEmpty {
                MiniTrendChart(values: viewModel.sparklineValues, lineColor: trendLineColor)
                    .accessibilityLabel("Net total trend")
            }
        }
        .padding(.vertical, 4)
    }

    var body: some View {
        @Bindable var model = viewModel

        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    summaryHeader
                        .padding(.horizontal, 12)
                        .padding(.top, 2)
                        .padding(.bottom, 10)

                    if model.sections.isEmpty {
                        ContentUnavailableView(
                            "No Transactions",
                            systemImage: "tray",
                            description: Text("Add your first transaction to get started.")
                        )
                        .padding(.top, 48)
                    } else {
                        ForEach(model.sections) { section in
                            VStack(spacing: 0) {
                                dayHeader(for: section)

                                ForEach(section.rows) { row in
                                    TransactionRowView(row: row)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingRow = row }
                                }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
            }
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

private struct SummaryAmountText: View {
    let valueMinor: Int64
    let currencyCode: String

    @Environment(\.locale) private var locale

    var body: some View {
        ViewThatFits(in: .horizontal) {
            amountLine(fontSize: 38)
            amountLine(fontSize: 34)
            amountLine(fontSize: 30)
            amountLine(fontSize: 26)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func amountLine(fontSize: CGFloat) -> some View {
        let prefix = valueMinor < 0 ? "-\(currencyCode)" : currencyCode
        let absMinor = valueMinor.ordinatioSafeAbs
        let digits = MoneyFormat.fractionDigits(for: currencyCode)
        let decimal = MoneyFormat.decimal(fromMinorUnits: absMinor, currencyCode: currencyCode)
        let number = decimal.formatted(.number.precision(.fractionLength(digits)).locale(locale))

        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(prefix)
                .font(.system(size: fontSize * 0.55, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(OrdinatioColor.textSecondary)

            Text(number)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(OrdinatioColor.textPrimary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct MiniSignedAmountText: View {
    let sign: String
    let absMinor: Int64
    let currencyCode: String
    let tint: Color

    @Environment(\.locale) private var locale

    var body: some View {
        let digits = MoneyFormat.fractionDigits(for: currencyCode)
        let decimal = MoneyFormat.decimal(fromMinorUnits: absMinor.ordinatioSafeAbs, currencyCode: currencyCode)
        let number = decimal.formatted(.number.precision(.fractionLength(digits)).locale(locale))
        Text("\(sign)\(number)")
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private extension Int64 {
    var ordinatioSafeAbs: Int64 {
        self == .min ? .max : Swift.abs(self)
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
        .frame(height: 34)
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
