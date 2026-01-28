import OrdinatioCore
import SwiftUI
import UIKit

struct TransactionsView: View {
    let db: DatabaseClient
    let householdId: String
    let defaultCurrencyCode: String

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    @State private var viewModel: TransactionListViewModel

    @State private var showFilters = false
    @State private var editingRow: TransactionListRow?
    @State private var deleteCandidate: TransactionListRow?
    @State private var isDeletePopperVisible = false
    @State private var deletePopperDismissTask: Task<Void, Never>?

    init(db: DatabaseClient, householdId: String, defaultCurrencyCode: String) {
        self.db = db
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        _viewModel = State(
            initialValue: TransactionListViewModel(
                db: db, householdId: householdId, defaultCurrencyCode: defaultCurrencyCode))
    }

    private func sectionTitle(for date: LocalDate) -> String {
        let value = date.date(calendar: calendar)
        if calendar.isDateInToday(value) { return "Today" }
        if calendar.isDateInYesterday(value) { return "Yesterday" }
        return date.formatted(dateStyle: .medium, locale: locale, calendar: calendar, timeZone: timeZone)
    }

    private func dayTotalText(for section: TransactionSection) -> String? {
        guard let currencyCode = viewModel.summaryCurrencyCode else { return nil }
        guard let netTotalMinor = section.netTotalMinor else { return nil }
        let formatted = MoneyFormat.format(
            minorUnits: netTotalMinor.ordinatioSafeAbs,
            currencyCode: currencyCode,
            locale: locale
        )
        if netTotalMinor > 0 { return "+\(formatted)" }
        if netTotalMinor < 0 { return "-\(formatted)" }
        return formatted
    }

    private func playOpenTransactionHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.9)
    }

    private func deleteTransaction(row: TransactionListRow) {
        Task { @MainActor in
            do {
                try await db.deleteTransaction(transactionId: row.id)
                dismissDeletePopper()
            } catch {
                viewModel.errorMessage = ErrorDisplay.message(error)
            }
        }
    }

    private func presentDeletePopper(row: TransactionListRow) {
        deletePopperDismissTask?.cancel()
        deleteCandidate = row
        withAnimation(.easeInOut(duration: 0.25)) {
            isDeletePopperVisible = true
        }
    }

    private func dismissDeletePopper() {
        deletePopperDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            isDeletePopperVisible = false
        }
        deletePopperDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            if Task.isCancelled { return }
            deleteCandidate = nil
        }
    }

    private func dayHeader(for section: TransactionSection) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(sectionTitle(for: section.date))
                    .textCase(.uppercase)

                Spacer()

                if let total = dayTotalText(for: section) {
                    Text(total)
                        .layoutPriority(1)
                }
            }
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .foregroundStyle(OrdinatioColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Line()
                .stroke(OrdinatioColor.separator, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
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

    private var multiCurrencyNetTotals: [(code: String, netTotalMinor: Int64)] {
        viewModel.netTotalMinorByCurrency
            .map { (code: $0.key, netTotalMinor: $0.value) }
            .sorted { $0.code < $1.code }
    }

    private var summaryTrendColor: Color {
        guard viewModel.sparklineValues.count > 1 else { return OrdinatioColor.textSecondary }
        let first = viewModel.sparklineValues.first ?? 0
        let last = viewModel.sparklineValues.last ?? 0
        if last > first { return OrdinatioColor.income }
        if last < first { return OrdinatioColor.expense }
        return OrdinatioColor.textSecondary
    }

    private var summaryHeader: some View {
        VStack(spacing: -3) {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text("Net total")
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textPrimary.opacity(0.9))

                    Menu {
                        ForEach(TransactionSummaryTimeFrame.allCases) { timeFrame in
                            Button(timeFrame.label) { viewModel.summaryTimeFrame = timeFrame }
                        }
                    } label: {
                        Text(viewModel.summaryTimeFrame.label)
                            .padding(2)
                            .padding(.horizontal, 6)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(OrdinatioColor.textPrimary.opacity(0.9))
                            .overlay {
                                Capsule()
                                    .stroke(OrdinatioColor.separator, lineWidth: 1.3)
                            }
                    }
                    .accessibilityLabel("Timeframe")
                }

                if let currencyCode = viewModel.summaryCurrencyCode, let netTotalMinor = viewModel.netTotalMinor {
                    NetTotalAmountText(valueMinor: netTotalMinor, currencyCode: currencyCode)
                        .accessibilityLabel(
                            MoneyFormat.format(minorUnits: netTotalMinor, currencyCode: currencyCode)
                        )
                } else if viewModel.availableCurrencyCodes.count > 1 {
                    if multiCurrencyNetTotals.isEmpty {
                        Text(currencySummaryText)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(multiCurrencyNetTotals.prefix(3), id: \.code) { item in
                                NetTotalCompactLine(valueMinor: item.netTotalMinor, currencyCode: item.code)
                            }

                            if multiCurrencyNetTotals.count > 3 {
                                Text("+\(multiCurrencyNetTotals.count - 3) more")
                                    .font(.system(.body, design: .rounded).weight(.medium))
                                    .foregroundStyle(OrdinatioColor.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.top, 5)
                    }
                } else {
                    Text("—")
                        .font(.system(.largeTitle, design: .rounded).weight(.regular))
                        .foregroundStyle(OrdinatioColor.textPrimary)
                }
            }
            .padding(7)
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())

            if let currencyCode = viewModel.summaryCurrencyCode,
                let income = viewModel.incomeTotalMinor,
                let expenseAbs = viewModel.expenseTotalAbsMinor,
                income > 0 || expenseAbs > 0
            {
                HStack {
                    if income > 0 {
                        Text("+\(formatAbsNumber(minorUnits: income, currencyCode: currencyCode, locale: locale))")
                            .font(.system(.title2, design: .rounded).weight(.medium))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(OrdinatioColor.income)
                            .lineLimit(1)
                    }

                    if income > 0 && expenseAbs > 0 {
                        DottedLine()
                            .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                            .frame(width: 1.7, height: 15)
                            .foregroundStyle(OrdinatioColor.separator)
                    }

                    if expenseAbs > 0 {
                        Text("-\(formatAbsNumber(minorUnits: expenseAbs, currencyCode: currencyCode, locale: locale))")
                            .font(.system(.title2, design: .rounded).weight(.medium))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(OrdinatioColor.expense)
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, 13)
            }

            if let currencyCode = viewModel.summaryCurrencyCode, viewModel.sparklineValues.count > 1 {
                MiniLineGraph(
                    values: viewModel.sparklineValues,
                    color: summaryTrendColor,
                    currencyCode: currencyCode,
                    timeFrame: viewModel.summaryTimeFrame
                )
                .accessibilityLabel("Net total trend")
                .frame(height: 25)
                .padding(.horizontal, 60)
                .padding(.top, 16)
            }
        }
    }

    var body: some View {
        @Bindable var model = viewModel

        let headerModels = model.sections.map {
            TransactionSectionHeaderModel(
                title: sectionTitle(for: $0.date),
                totalText: dayTotalText(for: $0)
            )
        }

        let summaryHeaderView = AnyView(
            summaryHeader
                .padding(.horizontal, 20)
                .padding(.top, 2)
                .padding(.bottom, 10)
                .background(OrdinatioColor.background)
        )

        NavigationStack {
            ZStack {
                TransactionsTableView(
                    sections: model.sections,
                    headerModels: headerModels,
                    summaryHeader: summaryHeaderView,
                    onSelectRow: { row in
                        playOpenTransactionHaptic()
                        editingRow = row
                    },
                    onEdit: { row in
                        playOpenTransactionHaptic()
                        editingRow = row
                    },
                    onDelete: { row in
                        presentDeletePopper(row: row)
                    },
                    onSwipeHaptic: {
                        let generator = UIImpactFeedbackGenerator(style: .rigid)
                        generator.prepare()
                        generator.impactOccurred(intensity: 0.75)
                    }
                )

                if model.sections.isEmpty {
                    ContentUnavailableView(
                        "No Transactions",
                        systemImage: "tray",
                        description: Text("Add your first transaction to get started.")
                    )
                    .padding(.top, 48)
                    .allowsHitTesting(false)
                }

                if let row = deleteCandidate {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .opacity(isDeletePopperVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.25), value: isDeletePopperVisible)
                        .allowsHitTesting(isDeletePopperVisible)
                        .onTapGesture {
                            dismissDeletePopper()
                        }
                }
            }
            .background(OrdinatioColor.background)
            .overlay(alignment: .bottom) {
                if let row = deleteCandidate {
                    DeleteTransactionBottomBar(
                        row: row,
                        onConfirm: { deleteTransaction(row: row) },
                        onCancel: {
                            dismissDeletePopper()
                        }
                    )
                    .padding(.horizontal, OrdinatioMetric.screenPadding)
                    .safeAreaPadding(.bottom, 12)
                    .frame(maxWidth: 520)
                    .offset(y: isDeletePopperVisible ? 0 : 280)
                    .opacity(isDeletePopperVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.25), value: isDeletePopperVisible)
                }
            }
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

private struct DeleteTransactionBottomBar: View {
    let row: TransactionListRow
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: OrdinatioMetric.cardCornerRadius, style: .continuous)
    }

    private var iconShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
    }

    private var handleShape: Capsule {
        Capsule()
    }

    private var categoryTitle: String {
        if let name = row.categoryName, !name.isEmpty { return name }
        return "Uncategorized"
    }

    private var categoryEmoji: String {
        OrdinatioCategoryVisuals.emoji(for: categoryTitle, iconIndex: row.categoryIconIndex)
    }

    private var categoryColor: Color {
        OrdinatioCategoryVisuals.color(for: categoryTitle, iconIndex: row.categoryIconIndex)
    }

    private var titleText: String {
        if let note = row.note, !note.isEmpty { return note }
        if let name = row.categoryName, !name.isEmpty { return name }
        return "Uncategorized"
    }

    private var subtitleText: String {
        let dateText = row.createdAt.formatted(date: .abbreviated, time: .shortened)
        if let note = row.note, !note.isEmpty {
            return "\(categoryTitle) · \(dateText)"
        }
        return dateText
    }

    private var amountText: String {
        let absMinor = row.amountMinor.ordinatioSafeAbs
        let formatted = MoneyFormat.format(minorUnits: absMinor, currencyCode: row.currencyCode, locale: locale)
        if row.amountMinor > 0 { return "+\(formatted)" }
        if row.amountMinor < 0 { return "-\(formatted)" }
        return formatted
    }

    private var amountColor: Color {
        row.amountMinor > 0 ? OrdinatioColor.income : OrdinatioColor.textPrimary
    }

    var body: some View {
        VStack(spacing: 16) {
            handleShape
                .fill(OrdinatioColor.separator.opacity(0.7))
                .frame(width: 46, height: 5)
                .padding(.top, 2)

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    iconShape
                        .fill(OrdinatioColor.expense.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay {
                            iconShape
                                .stroke(OrdinatioColor.expense.opacity(0.35), lineWidth: 1)
                        }

                    Image(systemName: "trash")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.expense)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Delete transaction")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textPrimary)

                    Text("This action can’t be undone")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }

                Spacer(minLength: 0)

                Text(amountText)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(amountColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(OrdinatioColor.surface)
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(OrdinatioColor.separator, lineWidth: 1)
                    }
            }

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(categoryColor.opacity(0.2))

                    Text(categoryEmoji)
                        .font(.system(.title3, design: .rounded))
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(titleText)
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textPrimary)
                        .lineLimit(2)

                    Text(subtitleText)
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(OrdinatioColor.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(OrdinatioColor.separator, lineWidth: 1)
            }

            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(OrdinatioColor.surface)
                        .foregroundStyle(OrdinatioColor.textPrimary)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(OrdinatioColor.separator, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Button(role: .destructive) {
                    onConfirm()
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(OrdinatioColor.expense)
                        .foregroundStyle(OrdinatioColor.lightIcon)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityIdentifier("TransactionDeleteConfirm")
            }
        }
        .padding(18)
        .background(
            cardShape
                .fill(OrdinatioColor.surfaceElevated)
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.35)
                        : Color.black.opacity(0.12),
                    radius: 16,
                    x: 0,
                    y: 8
                )
        )
        .overlay {
            cardShape.stroke(OrdinatioColor.separator, lineWidth: 1)
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        return path
    }
}

private struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width / 2, y: 0))
        path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height))
        return path
    }
}

private struct NetTotalAmountText: View {
    let valueMinor: Int64
    let currencyCode: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    private var prefix: String {
        valueMinor >= 0 ? "+\(currencyCode)" : "-\(currencyCode)"
    }

    private var numberText: String {
        let absMinor = valueMinor.ordinatioSafeAbs
        let digits = MoneyFormat.fractionDigits(for: currencyCode)
        let decimal = MoneyFormat.decimal(fromMinorUnits: absMinor, currencyCode: currencyCode)
        return decimal.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
    }

    private var numberFontSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall: 46
        case .small: 47
        case .medium: 48
        case .large: 50
        case .xLarge: 56
        case .xxLarge: 58
        case .xxxLarge: 62
        default: 50
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(prefix)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(OrdinatioColor.textSecondary)
            Text(numberText)
                .font(.system(size: numberFontSize, weight: .regular, design: .rounded))
                .foregroundStyle(OrdinatioColor.textPrimary)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

private struct NetTotalCompactLine: View {
    let valueMinor: Int64
    let currencyCode: String

    @Environment(\.locale) private var locale

    private var prefix: String {
        valueMinor >= 0 ? "+\(currencyCode)" : "-\(currencyCode)"
    }

    private var numberText: String {
        let absMinor = valueMinor.ordinatioSafeAbs
        let digits = MoneyFormat.fractionDigits(for: currencyCode)
        let decimal = MoneyFormat.decimal(fromMinorUnits: absMinor, currencyCode: currencyCode)
        return decimal.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(prefix)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(OrdinatioColor.textSecondary)

            Text(numberText)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(OrdinatioColor.textPrimary)
        }
        .minimumScaleFactor(0.65)
        .lineLimit(1)
    }
}

private struct MiniLineGraph: View {
    let values: [Int64]
    let color: Color
    let currencyCode: String
    let timeFrame: TransactionSummaryTimeFrame

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @State private var progress: CGFloat = 0

    @State private var currentIndex: Int?
    @State private var indicatorOffset: CGSize = .zero
    @State private var showIndicator = false
    @GestureState private var isDragging: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let points = graphPoints(in: proxy.size)
            let stepX = proxy.size.width / CGFloat(max(values.count - 1, 1))
            ZStack {
                if points.count > 1 {
                    AnimatedGraphPath(progress: progress, points: points)
                        .stroke(lineGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .shadow(color: color.opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 4, x: 0, y: 3)

                    if showIndicator, let currentIndex, points.indices.contains(currentIndex) {
                        MiniLineGraphIndicator(
                            label: label(for: currentIndex),
                            amountText: amountText(for: values[currentIndex]),
                            accentColor: color
                        )
                        .frame(width: 88)
                        .offset(y: 6)
                        .offset(indicatorOffset)
                        .opacity(showIndicator ? 1 : 0)
                        .accessibilityHidden(true)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard points.count > 1 else { return }
                        showIndicator = true

                        let x = min(max(value.location.x, 0), proxy.size.width)
                        let rawIndex = Int((x / stepX).rounded())
                        let clampedIndex = min(max(rawIndex, 1), values.count - 1)
                        currentIndex = clampedIndex

                        let point = points[clampedIndex]
                        indicatorOffset = CGSize(width: point.x - 44, height: point.y - proxy.size.height)
                    }
                    .onEnded { _ in
                        showIndicator = false
                    }
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
            )
        }
        .task(id: values) {
            progress = 0
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeInOut(duration: 1.15)) {
                progress = 1
            }
        }
        .onChange(of: isDragging) { _, dragging in
            if !dragging { showIndicator = false }
        }
    }

    private func graphPoints(in size: CGSize) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let height = size.height
        let stepX = size.width / CGFloat(values.count - 1)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0
        let range = maxValue - minValue

        return values.enumerated().map { index, value in
            let progress: CGFloat
            if range == 0 {
                progress = 0.5
            } else {
                progress = CGFloat(value - minValue) / CGFloat(range)
            }

            let y = -progress * height + height
            return CGPoint(x: CGFloat(index) * stepX, y: y)
        }
    }

    private var lineGradient: LinearGradient {
        let stop = 0.82
        return LinearGradient(
            gradient: Gradient(stops: [
                .init(color: OrdinatioColor.separator, location: max(0, stop - 0.015)),
                .init(color: color, location: stop),
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func label(for index: Int) -> String {
        guard index > 0 else { return "" }

        let now = Date()
        let startComponents: DateComponents

        switch timeFrame {
        case .today:
            startComponents = calendar.dateComponents([.year, .month, .day], from: now)
        case .thisWeek:
            startComponents = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: now)
        case .thisMonth:
            startComponents = calendar.dateComponents([.year, .month], from: now)
        case .thisYear:
            startComponents = calendar.dateComponents([.year], from: now)
        case .allTime:
            startComponents = calendar.dateComponents([.year, .month, .day], from: now)
        }

        guard let start = calendar.date(from: startComponents) else { return "" }

        let date: Date?
        if timeFrame == .thisYear {
            date = calendar.date(byAdding: .month, value: index - 1, to: start)
        } else {
            date = calendar.date(byAdding: .day, value: index - 1, to: start)
        }

        guard let date else { return "" }

        var style = Date.FormatStyle(date: .omitted, time: .omitted)
        style.locale = locale
        style.calendar = calendar
        style.timeZone = timeZone

        switch timeFrame {
        case .thisWeek:
            return date.formatted(style.weekday(.abbreviated))
        case .thisYear:
            return date.formatted(style.month(.abbreviated))
        case .today, .thisMonth, .allTime:
            return date.formatted(style.month(.abbreviated).day())
        }
    }

    private func amountText(for valueMinor: Int64) -> String {
        let absMinor = valueMinor.ordinatioSafeAbs
        let digits = MoneyFormat.fractionDigits(for: currencyCode)
        let decimal = MoneyFormat.decimal(fromMinorUnits: absMinor, currencyCode: currencyCode)
        let number = decimal.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
        let prefix = valueMinor >= 0 ? "+\(currencyCode)" : "-\(currencyCode)"
        return "\(prefix) \(number)"
    }
}

private struct MiniLineGraphIndicator: View {
    let label: String
    let amountText: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(OrdinatioColor.textSecondary)

                Text(amountText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(OrdinatioColor.textPrimary)
            }
            .frame(height: 33)
            .padding(.horizontal, 7)
            .background(OrdinatioColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.bottom, 4)

            DottedLine()
                .stroke(style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 2.5, height: 25)
                .foregroundStyle(accentColor)

            Circle()
                .stroke(OrdinatioColor.background, lineWidth: 2.5)
                .background(Circle().fill(accentColor))
                .frame(width: 14, height: 11)
        }
    }
}

private struct AnimatedGraphPath: Shape {
    var progress: CGFloat
    var points: [CGPoint]

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in _: CGRect) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            path.addLines(points)
        }
        .trimmedPath(from: 0, to: progress)
    }
}

extension Int64 {
    fileprivate var ordinatioSafeAbs: Int64 {
        self == .min ? .max : Swift.abs(self)
    }
}

private func formatAbsNumber(minorUnits: Int64, currencyCode: String, locale: Locale) -> String {
    let absMinor = minorUnits.ordinatioSafeAbs
    let digits = MoneyFormat.fractionDigits(for: currencyCode)
    let decimal = MoneyFormat.decimal(fromMinorUnits: absMinor, currencyCode: currencyCode)
    return decimal.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
}
