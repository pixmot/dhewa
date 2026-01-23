import SwiftUI
import UIKit
import OrdinatioCore

struct BudgetDetailView: View {
    let budgetId: String
    let database: AppDatabase
    let householdId: String
    let defaultCurrencyCode: String
    @ObservedObject var viewModel: BudgetsViewModel

    @Environment(\.dismiss) private var dismiss
    @StateObject private var transactionsViewModel: BudgetTransactionsViewModel

    @State private var selectedStartDate: Date = Date()
    @State private var composerRoute: BudgetComposerRoute?
    @State private var composerDetent: PresentationDetent = .medium
    @State private var showDeleteConfirm = false
    @State private var showAddTransaction = false
    @State private var editingTransaction: TransactionListRow?
    @State private var pendingDeleteTransaction: TransactionListRow?

    init(
        budgetId: String,
        database: AppDatabase,
        householdId: String,
        defaultCurrencyCode: String,
        viewModel: BudgetsViewModel
    ) {
        self.budgetId = budgetId
        self.database = database
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        self.viewModel = viewModel
        _transactionsViewModel = StateObject(wrappedValue: BudgetTransactionsViewModel(database: database, householdId: householdId))
    }

    private var snapshot: BudgetSnapshot? {
        viewModel.snapshots.first { $0.budget.id == budgetId }
    }

    private func presentComposer(_ route: BudgetComposerRoute) {
        composerDetent = .medium
        composerRoute = route
    }

    var body: some View {
        VStack(spacing: 15) {
            topBar

            if let snapshot {
                DimeBudgetDetailContent(
                    snapshot: snapshot,
                    selectedStartDate: $selectedStartDate,
                    transactionsViewModel: transactionsViewModel,
                    onEditTransaction: { editingTransaction = $0 },
                    onDeleteTransactionRequest: { pendingDeleteTransaction = $0 },
                    onDeleteTransactionImmediate: { transactionsViewModel.deleteTransaction(id: $0.id) }
                )
            } else {
                Text("Budget not found")
                    .font(.headline)
                    .foregroundStyle(OrdinatioColor.textSecondary)
            }
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OrdinatioColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            if let snapshot {
                selectedStartDate = snapshot.period.start
                transactionsViewModel.configure(budget: snapshot.budget, startDate: selectedStartDate)
            }
        }
        .onChange(of: selectedStartDate) { newValue in
            transactionsViewModel.updatePeriod(startDate: newValue)
        }
        .onChange(of: snapshot?.budget) { newBudget in
            if let newBudget {
                let normalized = BudgetDateHelper.period(for: newBudget).start
                selectedStartDate = normalized
                transactionsViewModel.configure(budget: newBudget, startDate: normalized)
            }
        }
        .sheet(item: $composerRoute) { route in
            let existingCategoryBudgetIds = Set(viewModel.categorySnapshots.compactMap { $0.budget.categoryId })
                BudgetComposerView(
                    route: route,
                    database: database,
                    householdId: householdId,
                    categories: viewModel.categories,
                    existingCategoryBudgetIds: existingCategoryBudgetIds,
                    defaultCurrencyCode: defaultCurrencyCode,
                    onSave: { draft in
                        if let budgetId = draft.budgetId {
                            viewModel.updateBudget(
                                budgetId: budgetId,
                                isOverall: draft.isOverall,
                                categoryId: draft.categoryId,
                                timeFrame: draft.timeFrame,
                                startDate: draft.startDate,
                                currencyCode: draft.currencyCode,
                                amountMinor: draft.amountMinor
                            )
                        } else {
                            viewModel.upsertBudget(
                                isOverall: draft.isOverall,
                                categoryId: draft.categoryId,
                                timeFrame: draft.timeFrame,
                                startDate: draft.startDate,
                                currencyCode: draft.currencyCode,
                                amountMinor: draft.amountMinor
                            )
                        }
                    }
                )
                .presentationDetents([.medium, .large], selection: $composerDetent)
                .presentationDragIndicator(.visible)
            }
        .fullScreenCover(item: $editingTransaction) { row in
            TransactionEditorView(
                database: database,
                householdId: householdId,
                defaultCurrencyCode: row.currencyCode,
                mode: .edit(row),
                showsDismissButton: true
            )
        }
        .confirmationDialog(
            "Delete this budget?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let snapshot {
                    viewModel.deleteBudget(id: snapshot.budget.id)
                    dismiss()
                }
            }
        }
        .confirmationDialog(
            "Delete this transaction?",
            isPresented: Binding(
                get: { pendingDeleteTransaction != nil },
                set: { newValue in
                    if !newValue { pendingDeleteTransaction = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let row = pendingDeleteTransaction {
                    transactionsViewModel.deleteTransaction(id: row.id)
                }
                pendingDeleteTransaction = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteTransaction = nil
            }
        }
        .fullScreenCover(isPresented: $showAddTransaction) {
            if let snapshot, let categoryId = snapshot.budget.categoryId {
                TransactionEditorView(
                    database: database,
                    householdId: householdId,
                    defaultCurrencyCode: snapshot.budget.currencyCode,
                    mode: .create,
                    showsDismissButton: true,
                    prefilledCategoryId: categoryId
                )
            }
        }
        .alert("Error", isPresented: Binding(get: {
            transactionsViewModel.errorMessage != nil
        }, set: { newValue in
            if !newValue { transactionsViewModel.errorMessage = nil }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(transactionsViewModel.errorMessage ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("Back")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                }
                .foregroundStyle(OrdinatioColor.textSecondary)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .fixedSize(horizontal: false, vertical: true)
                .background(OrdinatioColor.surfaceElevated, in: Capsule())
            }

            Spacer()

            if let snapshot {
                if !snapshot.budget.isOverall {
                    BudgetTopBarButton(symbol: "plus", tint: OrdinatioColor.actionBlue) {
                        showAddTransaction = true
                    }
                }

                BudgetTopBarButton(symbol: "pencil", tint: OrdinatioColor.actionOrange) {
                    presentComposer(.edit(snapshot))
                }

                BudgetTopBarButton(symbol: "trash.fill", tint: OrdinatioColor.expense) {
                    showDeleteConfirm = true
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct BudgetTopBarButton: View {
    let symbol: String
    let tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(tint)
                .padding(8)
                .background(tint.opacity(0.23), in: Circle())
                .contentShape(Circle())
        }
    }
}

private struct DimeBudgetDetailContent: View {
    let snapshot: BudgetSnapshot
    @Binding var selectedStartDate: Date
    @ObservedObject var transactionsViewModel: BudgetTransactionsViewModel
    var onEditTransaction: (TransactionListRow) -> Void
    var onDeleteTransactionRequest: (TransactionListRow) -> Void
    var onDeleteTransactionImmediate: (TransactionListRow) -> Void

    @State private var animatedRemainingFraction: Double = 0

    private var period: BudgetPeriod {
        BudgetDateHelper.period(for: snapshot.budget.timeFrame, startDate: selectedStartDate)
    }

    private var currentStartDate: Date {
        BudgetDateHelper.normalizedStartDate(for: snapshot.budget)
    }

    private var isCurrentPeriod: Bool {
        LocalDate.from(date: selectedStartDate).yyyymmdd == LocalDate.from(date: currentStartDate).yyyymmdd
    }

    private var budgetAmount: Int64 { abs(snapshot.budget.amountMinor) }
    private var spentAmount: Int64 { abs(transactionsViewModel.spentAbsMinor) }
    private var difference: Int64 { abs(budgetAmount - spentAmount) }

    private var highlightOver: Bool { budgetAmount > 0 && spentAmount >= budgetAmount }
    private var isOver: Bool { budgetAmount > 0 && spentAmount > budgetAmount }

    private var dateRangeText: String {
        dateRangeString(for: snapshot.budget.timeFrame, start: period.start, end: period.end)
    }

    private var subtitleText: String {
        isCurrentPeriod ? timeLeftText : dateRangeText
    }

    private var timeLeftText: String {
        switch snapshot.budget.timeFrame {
        case .day:
            return "\(period.hoursLeft()) hours left"
        default:
            return "\(period.daysLeft()) days left"
        }
    }

    private var differenceSubtitle: String {
        let prefix = isOver ? "over" : "left"
        if isCurrentPeriod {
            return "\(prefix) \(snapshot.budget.timeFrame.periodLabel)"
        }

        let calendar = Calendar.current

        switch snapshot.budget.timeFrame {
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return "\(prefix) on \(formatter.string(from: period.start))"
        case .week:
            let days = calendar.dateComponents([.day], from: period.start, to: currentStartDate).day ?? 0
            let weeks = max(days / 7, 1)
            return "\(prefix) \(weeks) week\(weeks == 1 ? "" : "s") ago"
        case .month:
            let months = calendar.dateComponents([.month], from: period.start, to: currentStartDate).month ?? 0
            let value = max(months, 1)
            return "\(prefix) \(value) month\(value == 1 ? "" : "s") ago"
        case .year:
            let years = calendar.dateComponents([.year], from: period.start, to: currentStartDate).year ?? 0
            let value = max(years, 1)
            return "\(prefix) \(value) year\(value == 1 ? "" : "s") ago"
        }
    }

    private var showPerDay: Bool {
        snapshot.budget.timeFrame != .day
            && spentAmount < budgetAmount
            && isCurrentPeriod
            && period.daysLeft() > 1
    }

    private var leftPerDayMinor: Int64 {
        guard snapshot.budget.timeFrame != .day else { return 0 }
        let daysLeft = max(period.daysLeft(), 1)
        return max((budgetAmount - spentAmount) / Int64(daysLeft), 0)
    }

    private var spentFraction: Double {
        guard budgetAmount > 0 else { return 0 }
        return Double(spentAmount) / Double(budgetAmount)
    }

    private var remainingFraction: Double {
        max(min(1 - spentFraction, 1), 0)
    }

    private var earliestTransactionDate: Date {
        guard let oldestTxnDate = transactionsViewModel.earliestTxnDate else {
            return Date()
        }
        return LocalDate(yyyymmdd: oldestTxnDate).date()
    }

    private var barColor: Color {
        if snapshot.budget.isOverall {
            return OrdinatioColor.darkBackground
        }
        if let category = snapshot.category {
            return OrdinatioCategoryVisuals.color(for: category.name)
        }
        return OrdinatioColor.textPrimary
    }

    var body: some View {
        VStack(spacing: 20) {
            header

            differenceSection

            barSection

            if snapshot.budget.timeFrame == .day {
                Divider()
                    .overlay(OrdinatioColor.separator)
                    .padding(.horizontal, 25)
            }

            transactionsSection

            DimeBudgetPeriodStepper(
                startDate: $selectedStartDate,
                timeFrame: snapshot.budget.timeFrame,
                currentStartDate: currentStartDate,
                earliestTransactionDate: earliestTransactionDate,
                dateRangeText: dateRangeText
            )
            .padding(.horizontal, 25)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            animatedRemainingFraction = 0
            withAnimation(.easeInOut(duration: 0.7)) {
                animatedRemainingFraction = remainingFraction
            }
        }
        .onChange(of: remainingFraction) { _, newValue in
            withAnimation(.easeInOut(duration: 0.7)) {
                animatedRemainingFraction = newValue
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            if snapshot.budget.isOverall {
                Text("Overall Budget")
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(OrdinatioColor.textPrimary)
            } else if let category = snapshot.category {
                HStack(spacing: 7.5) {
                    Text(OrdinatioCategoryVisuals.emoji(for: category.name))
                        .font(.system(.subheadline, design: .rounded))

                    Text(category.name)
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .lineLimit(1)
                }
                .foregroundStyle(OrdinatioColor.textPrimary)
            } else {
                Text("Budget")
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(OrdinatioColor.textPrimary)
            }

            Text(subtitleText)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(OrdinatioColor.textSecondary)
                .padding(4)
                .padding(.horizontal, 7)
                .background(OrdinatioColor.surfaceElevated, in: Capsule())
        }
        .padding(.bottom, 15)
    }

    @ViewBuilder
    private var differenceSection: some View {
        if snapshot.budget.timeFrame == .day {
            VStack(spacing: -4) {
                DimeDetailMoneyView(
                    amountMinor: difference,
                    currencyCode: snapshot.budget.currencyCode,
                    highlight: highlightOver
                )

                Text(differenceSubtitle)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textSecondary)
            }
            .padding(.horizontal, 25)
        } else {
            HStack(alignment: .top, spacing: 15) {
                VStack(alignment: showPerDay ? .leading : .center, spacing: -4) {
                    DimeDetailMoneyView(
                        amountMinor: difference,
                        currencyCode: snapshot.budget.currencyCode,
                        highlight: highlightOver
                    )

                    Text(differenceSubtitle)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: showPerDay ? .leading : .center)

                if showPerDay {
                    VStack(alignment: .trailing, spacing: -4) {
                        DimeDetailMoneyView(
                            amountMinor: leftPerDayMinor,
                            currencyCode: snapshot.budget.currencyCode,
                            highlight: false
                        )

                        Text("left each day")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 25)
        }
    }

    private var barSection: some View {
        VStack(spacing: 5) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                        .fill(OrdinatioColor.surfaceElevated)
                        .frame(width: proxy.size.width)

                    if budgetAmount > 0, spentFraction < 0.98 {
                        RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                            .fill(barColor)
                            .frame(width: proxy.size.width * animatedRemainingFraction)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 28)

            HStack {
                Text("\(currencySymbol(for: snapshot.budget.currencyCode))\(barNumberString(absMinor: spentAmount))")
                Spacer()
                Text("\(currencySymbol(for: snapshot.budget.currencyCode))\(barNumberString(absMinor: budgetAmount))")
            }
            .frame(maxWidth: .infinity)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(OrdinatioColor.textSecondary)
        }
        .padding(.bottom, snapshot.budget.timeFrame == .day ? 0 : 20)
        .padding(.horizontal, 25)
    }

    private var transactionsSection: some View {
        ScrollView(showsIndicators: false) {
            if transactionsViewModel.rows.isEmpty {
                DimeNoResultsView()
                    .padding(.top, 40)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(transactionSections) { section in
                        DimeBudgetTransactionDaySection(
                            txnDate: section.txnDate,
                            currencyCode: snapshot.budget.currencyCode,
                            rows: section.rows,
                            onEdit: onEditTransaction,
                            onDeleteRequest: onDeleteTransactionRequest,
                            onDeleteImmediate: onDeleteTransactionImmediate
                        )
                        .padding(.bottom, 18)
                    }
                }
                .padding(.horizontal, 15)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func dateRangeString(for frame: BudgetTimeFrame, start: Date, end: Date) -> String {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: -1, to: end) ?? end
        let formatter = DateFormatter()

        switch frame {
        case .day:
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: start)
        case .week, .month:
            formatter.dateFormat = "d MMM"
            return formatter.string(from: start) + " - " + formatter.string(from: endDate)
        case .year:
            formatter.dateFormat = "d MMM yy"
            return formatter.string(from: start) + " - " + formatter.string(from: endDate)
        }
    }

    private func currencySymbol(for currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        return formatter.currencySymbol ?? currencyCode.uppercased()
    }

    private func barNumberString(absMinor: Int64) -> String {
        let decimal = MoneyFormat.decimal(fromMinorUnits: absMinor, currencyCode: snapshot.budget.currencyCode)
        let value = (NSDecimalNumber(decimal: decimal)).doubleValue
        return String(format: "%.2f", value)
    }

    private var transactionSections: [DimeBudgetTransactionSection] {
        var sections: [DimeBudgetTransactionSection] = []
        var currentDate: Int32?
        var currentRows: [TransactionListRow] = []

        for row in transactionsViewModel.rows {
            if currentDate == nil {
                currentDate = row.txnDate
            }

            if row.txnDate != currentDate {
                if let currentDate {
                    sections.append(DimeBudgetTransactionSection(txnDate: currentDate, rows: currentRows))
                }
                currentDate = row.txnDate
                currentRows = []
            }

            currentRows.append(row)
        }

        if let currentDate {
            sections.append(DimeBudgetTransactionSection(txnDate: currentDate, rows: currentRows))
        }

        return sections
    }
}

private struct DimeBudgetTransactionSection: Identifiable, Hashable {
    let txnDate: Int32
    let rows: [TransactionListRow]

    var id: Int32 { txnDate }
}

private struct DimeBudgetTransactionDaySection: View {
    let txnDate: Int32
    let currencyCode: String
    let rows: [TransactionListRow]
    var onEdit: (TransactionListRow) -> Void
    var onDeleteRequest: (TransactionListRow) -> Void
    var onDeleteImmediate: (TransactionListRow) -> Void

    private var date: Date { LocalDate(yyyymmdd: txnDate).date() }
    private var dateText: String { dimeDateConverter(date: date).uppercased() }

    private var totalMinor: Int64 {
        rows.reduce(Int64(0)) { partialResult, row in
            partialResult + row.amountMinor
        }
    }

    private var totalString: String {
        if totalMinor >= 0 {
            return "+" + MoneyFormat.format(minorUnits: totalMinor, currencyCode: currencyCode)
        }
        return MoneyFormat.format(minorUnits: totalMinor, currencyCode: currencyCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack {
                    Text(dateText)
                    Spacer()
                    Text(totalString)
                        .layoutPriority(1)
                }
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(OrdinatioColor.textSecondary)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(OrdinatioColor.separator)
                    .frame(height: 1.3)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)

            ForEach(rows) { row in
                DimeBudgetTransactionRow(
                    row: row,
                    currencyCode: currencyCode,
                    onEdit: onEdit,
                    onDeleteRequest: onDeleteRequest,
                    onDeleteImmediate: onDeleteImmediate
                )
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct DimeBudgetTransactionRow: View {
    let row: TransactionListRow
    let currencyCode: String
    var onEdit: (TransactionListRow) -> Void
    var onDeleteRequest: (TransactionListRow) -> Void
    var onDeleteImmediate: (TransactionListRow) -> Void

    @State private var offset: CGFloat = 0
    @State private var deleted = false
    @GestureState private var isDragging = false

    private var deletePopup: Bool {
        abs(offset) > UIScreen.main.bounds.width * 0.2
    }

    private var deleteConfirm: Bool {
        abs(offset) > UIScreen.main.bounds.width * 0.42
    }

    private var title: String {
        let trimmed = (row.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let category = row.categoryName, !category.isEmpty { return category }
        return "Expense"
    }

    private var subtitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: row.createdAt)
    }

    private var categoryName: String {
        row.categoryName?.isEmpty == false ? (row.categoryName ?? "") : "Uncategorized"
    }

    private var emoji: String { OrdinatioCategoryVisuals.emoji(for: categoryName) }
    private var color: Color { OrdinatioCategoryVisuals.color(for: categoryName) }

    private var amountString: String {
        let formatted = MoneyFormat.format(minorUnits: abs(row.amountMinor), currencyCode: currencyCode)
        return "-\(formatted)"
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Image(systemName: "xmark")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(deleteConfirm ? OrdinatioColor.expense : OrdinatioColor.textSecondary)
                .padding(5)
                .background(deleteConfirm ? OrdinatioColor.expense.opacity(0.23) : OrdinatioColor.surfaceElevated, in: Circle())
                .scaleEffect(deleteConfirm ? 1.1 : 1)
                .contentShape(Circle())
                .opacity(deleted ? 0 : 1)
                .padding(.horizontal, 10)
                .offset(x: 80)
                .offset(x: max(-80, offset))

            HStack(spacing: 12) {
                DimeEmojiTile(emoji: emoji, color: color)
                    .fixedSize()

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textPrimary)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(amountString)
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textPrimary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture { onEdit(row) }
            .contextMenu {
                Button {
                    onEdit(row)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDeleteRequest(row)
                } label: {
                    Label("Delete", systemImage: "xmark.bin")
                }
            }
            .offset(x: offset)
        }
        .onChange(of: deletePopup) { _ in
            if deletePopup {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .onChange(of: deleteConfirm) { _ in
            if deleteConfirm {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .animation(.easeInOut, value: deletePopup)
        .simultaneousGesture(
            DragGesture()
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    if value.translation.width < 0 {
                        withAnimation {
                            offset = value.translation.width
                        }
                    }
                }
                .onEnded { _ in
                    if deleteConfirm {
                        deleted = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            offset -= UIScreen.main.bounds.width
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            onDeleteImmediate(row)
                        }
                    } else if deletePopup {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            offset = 0
                        }
                        onDeleteRequest(row)
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            offset = 0
                        }
                    }
                }
        )
        .onChange(of: isDragging) { newValue in
            if !newValue && !deleted {
                withAnimation(.easeInOut(duration: 0.3)) {
                    offset = 0
                }
            }
        }
    }
}

private struct DimeEmojiTile: View {
    let emoji: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(dimeBlendedColor)
            Text(emoji)
                .font(.system(.title3, design: .rounded))
                .padding(8)
        }
    }

    private var dimeBlendedColor: Color {
        guard let uiColor = UIColor(color).cgColor.components, uiColor.count >= 3 else {
            return color.opacity(0.35)
        }

        let alpha: CGFloat = 0.73
        let red = (uiColor[0] * alpha) + (1 * (1 - alpha))
        let green = (uiColor[1] * alpha) + (1 * (1 - alpha))
        let blue = (uiColor[2] * alpha) + (1 * (1 - alpha))
        return Color(UIColor(red: red, green: green, blue: blue, alpha: 1))
    }
}

private struct DimeNoResultsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.full.fill")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(OrdinatioColor.textSecondary.opacity(0.7))

            Text("No results.")
                .font(.system(.title3, design: .rounded).weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(OrdinatioColor.textSecondary.opacity(0.7))
        }
    }
}

private func dimeDateConverter(date: Date, calendar: Calendar = .current) -> String {
    let calendar = calendar
    let year = calendar.component(.year, from: Date())
    let startOfYear = calendar.date(from: DateComponents(year: year)) ?? Date()

    if calendar.isDateInToday(date) {
        return "today"
    }
    if calendar.isDateInYesterday(date) {
        return "yesterday"
    }

    let formatter = DateFormatter()
    if startOfYear > date {
        formatter.dateFormat = "EEE, d MMM yy"
        var string = formatter.string(from: date)
        if string.count >= 2 {
            string.insert("'", at: string.index(string.endIndex, offsetBy: -2))
        }
        return string
    } else {
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: date)
    }
}

private struct DimeDetailMoneyView: View {
    let amountMinor: Int64
    let currencyCode: String
    let highlight: Bool

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        return formatter.currencySymbol ?? currencyCode.uppercased()
    }

    private var majorValue: Double {
        let decimal = MoneyFormat.decimal(fromMinorUnits: abs(amountMinor), currencyCode: currencyCode)
        return (NSDecimalNumber(decimal: decimal)).doubleValue
    }

    private var amountString: String {
        let showCents = majorValue < 100
        return String(format: showCents ? "%.2f" : "%.0f", majorValue)
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(currencySymbol)
                .font(.system(.title2, design: .rounded).weight(.medium))
                .foregroundStyle(highlight ? OrdinatioColor.expense : OrdinatioColor.textSecondary)

            Text(amountString)
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
                .foregroundStyle(highlight ? OrdinatioColor.expense : OrdinatioColor.textPrimary)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

private struct DimeBudgetPeriodStepper: View {
    @Binding var startDate: Date
    let timeFrame: BudgetTimeFrame
    let currentStartDate: Date
    let earliestTransactionDate: Date
    let dateRangeText: String

    var body: some View {
        HStack {
            DimeStepperButton(symbol: "chevron.left", disabled: !canShiftBackward) {
                shift(by: -1)
            }

            Spacer()

            Text(dateRangeText)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(OrdinatioColor.textPrimary)

            Spacer()

            DimeStepperButton(symbol: "chevron.right", disabled: !canShiftForward) {
                shift(by: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var canShiftBackward: Bool {
        LocalDate.from(date: startDate) > LocalDate.from(date: earliestTransactionDate)
    }

    private var canShiftForward: Bool {
        LocalDate.from(date: startDate) < LocalDate.from(date: currentStartDate)
    }

    private func shift(by offset: Int) {
        if offset > 0, !canShiftForward { return }
        if offset < 0, !canShiftBackward { return }

        let calendar = Calendar.current
        let newDate: Date?

        switch timeFrame {
        case .day:
            newDate = calendar.date(byAdding: .day, value: offset, to: startDate)
        case .week:
            newDate = calendar.date(byAdding: .day, value: offset * 7, to: startDate)
        case .month:
            newDate = calendar.date(byAdding: .month, value: offset, to: startDate)
        case .year:
            newDate = calendar.date(byAdding: .year, value: offset, to: startDate)
        }

        if let newDate {
            startDate = newDate
        }
    }
}

private struct DimeStepperButton: View {
    let symbol: String
    let disabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(OrdinatioColor.textSecondary)
                .padding(8)
                .background(OrdinatioColor.surfaceElevated, in: Circle())
                .opacity(disabled ? 0.3 : 1)
        }
        .disabled(disabled)
    }
}
