import SwiftUI
import UIKit
import OrdinatioCore

struct BudgetsView: View {
    let database: AppDatabase
    let householdId: String
    let defaultCurrencyCode: String

    @StateObject private var viewModel: BudgetsViewModel
    @AppStorage(PreferencesKeys.budgetRows) private var budgetRows = false

    @State private var composerRoute: BudgetComposerRoute?
    @State private var composerDetent: PresentationDetent = .fraction(0.9)
    @State private var pendingDelete: BudgetSnapshot?

    init(database: AppDatabase, householdId: String, defaultCurrencyCode: String) {
        self.database = database
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        _viewModel = StateObject(wrappedValue: BudgetsViewModel(database: database, householdId: householdId))
    }

    private func presentComposer(_ route: BudgetComposerRoute) {
        switch route {
        case .create:
            composerDetent = .fraction(0.9)
        case .edit:
            composerDetent = .fraction(0.9)
        }
        composerRoute = route
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OrdinatioColor.background
                    .ignoresSafeArea()

                if viewModel.categories.isEmpty && viewModel.snapshots.isEmpty {
                    BudgetIntroEmptyState()
                        .padding(.horizontal, 30)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea(.all)
                } else {
                    VStack(spacing: 0) {
                        BudgetsHeaderView()
                        .padding(.top, 20)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 20)

                        if viewModel.snapshots.isEmpty {
                            BudgetNoBudgetsState()
                                .padding(.horizontal, 30)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 0) {
                                    if let overall = viewModel.overallSnapshot {
                                        NavigationLink {
                                            BudgetDetailView(
                                                budgetId: overall.budget.id,
                                                database: database,
                                                householdId: householdId,
                                                defaultCurrencyCode: defaultCurrencyCode,
                                                viewModel: viewModel
                                            )
                                        } label: {
                                            DimeMainBudgetCard(
                                                snapshot: overall,
                                                soloBudget: viewModel.categorySnapshots.isEmpty
                                            )
                                            .contextMenu {
                                                Button { presentComposer(.edit(overall)) } label: {
                                                    Label("Edit", systemImage: "pencil")
                                                }
                                                Button(role: .destructive) { pendingDelete = overall } label: {
                                                    Label("Delete", systemImage: "xmark.bin")
                                                }
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal, 25)
                                        .padding(.bottom, 15)
                                    }

                                    if budgetRows {
                                        VStack(spacing: 10) {
                                            ForEach(viewModel.categorySnapshots) { snapshot in
                                                NavigationLink {
                                                    BudgetDetailView(
                                                        budgetId: snapshot.budget.id,
                                                        database: database,
                                                        householdId: householdId,
                                                        defaultCurrencyCode: defaultCurrencyCode,
                                                        viewModel: viewModel
                                                    )
                                                } label: {
                                                    DimeBudgetRowCard(
                                                        snapshot: snapshot,
                                                        onEdit: { presentComposer(.edit(snapshot)) },
                                                        onDeleteRequest: { pendingDelete = snapshot },
                                                        onDeleteImmediate: { viewModel.deleteBudget(id: snapshot.budget.id) }
                                                    )
                                                    .contextMenu {
                                                        Button { presentComposer(.edit(snapshot)) } label: {
                                                            Label("Edit", systemImage: "pencil")
                                                        }
                                                        Button(role: .destructive) { pendingDelete = snapshot } label: {
                                                            Label("Delete", systemImage: "xmark.bin")
                                                        }
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    } else {
                                        LazyVGrid(
                                            columns: [
                                                GridItem(.flexible(), spacing: 15),
                                                GridItem(.flexible(), spacing: 15),
                                            ],
                                            spacing: 15
                                        ) {
                                            ForEach(viewModel.categorySnapshots) { snapshot in
                                                NavigationLink {
                                                    BudgetDetailView(
                                                        budgetId: snapshot.budget.id,
                                                        database: database,
                                                        householdId: householdId,
                                                        defaultCurrencyCode: defaultCurrencyCode,
                                                        viewModel: viewModel
                                                    )
                                                } label: {
                                                    DimeBudgetGridCard(snapshot: snapshot)
                                                        .contextMenu {
                                                            Button { presentComposer(.edit(snapshot)) } label: {
                                                                Label("Edit", systemImage: "pencil")
                                                            }
                                                            Button(role: .destructive) { pendingDelete = snapshot } label: {
                                                                Label("Delete", systemImage: "xmark.bin")
                                                            }
                                                        }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 25)
                                        .padding(5)
                                    }
                                }
                                .padding(.bottom, 70)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }

            }
            .overlay(alignment: .bottomTrailing) {
                BudgetCreateButton {
                    presentComposer(.create(overallExists: viewModel.overallSnapshot != nil))
                }
                .padding(.trailing, 20)
                .padding(.bottom, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
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
                .presentationDetents([.fraction(0.9), .large], selection: $composerDetent)
                .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $pendingDelete) { snapshot in
                BudgetDeleteAlert(
                    snapshot: snapshot,
                    onDelete: {
                        viewModel.deleteBudget(id: snapshot.budget.id)
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
            .task {
                viewModel.refreshBudgetsForCurrentPeriod()
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
    }
}

enum BudgetComposerRoute: Identifiable {
    case create(overallExists: Bool)
    case edit(BudgetSnapshot)

    var id: String {
        switch self {
        case let .create(overallExists):
            return "create_\(overallExists ? 1 : 0)"
        case let .edit(snapshot):
            return "edit_\(snapshot.id)"
        }
    }
}

private struct BudgetsHeaderView: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Budgets")
                .font(.system(.title, design: .rounded).weight(.semibold))
                .foregroundStyle(OrdinatioColor.textPrimary)
                .accessibility(addTraits: .isHeader)

            Spacer()
        }
    }
}

private struct BudgetCreateButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Create Budget", systemImage: "plus")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(OrdinatioColor.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(LiquidGlassCapsule())
        }
        .buttonStyle(.plain)
    }
}

private struct LiquidGlassCapsule: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.18 : 0.55),
                        lineWidth: 1
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.45),
                                Color.white.opacity(0.08),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12),
                radius: 10,
                x: 0,
                y: 6
            )
    }
}

private struct BudgetIntroEmptyState: View {
    var body: some View {
        VStack(spacing: 5) {
            BudgetIntroIllustration()
                .padding(.bottom, 20)

            Text("Budget Your Finances")
                .font(.system(.title2, design: .rounded).weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(OrdinatioColor.textPrimary.opacity(0.85))

            Text("Link budgets to categories and set appropriate expenditure goals")
                .font(.system(.body, design: .rounded).weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(OrdinatioColor.textSecondary.opacity(0.8))
        }
        .frame(height: 250, alignment: .top)
        .padding(.top, 10)
    }
}

private struct BudgetIntroIllustration: View {
    var body: some View {
        ZStack {
            BudgetIntroTile(emoji: "🛒", color: Color(red: 0.16, green: 0.60, blue: 0.96))
                .offset(x: -18, y: -8)
            BudgetIntroTile(emoji: "🍽️", color: Color(red: 0.93, green: 0.48, blue: 0.35))
                .offset(x: 18, y: -8)
            BudgetIntroTile(emoji: "🚗", color: Color(red: 0.67, green: 0.40, blue: 0.64))
                .offset(x: 0, y: 18)
        }
        .frame(width: 75, height: 75)
    }
}

private struct BudgetIntroTile: View {
    let emoji: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(0.35))
            Text(emoji)
                .font(.system(size: 26))
        }
        .frame(width: 44, height: 44)
    }
}

private struct BudgetNoBudgetsState: View {
    var body: some View {
        VStack(spacing: 5) {
            Spacer()
            Text("🙈")
                .font(.system(.largeTitle, design: .rounded))
                .padding(.bottom, 9)

            Text("No Budgets Found")
                .font(.system(.title2, design: .rounded).weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(OrdinatioColor.textPrimary.opacity(0.85))

            Text("Add your first budget today!")
                .font(.system(.body, design: .rounded).weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(OrdinatioColor.textSecondary.opacity(0.8))
            Spacer()
            Spacer()
        }
        .padding(20)
    }
}

private struct OverallBudgetCard: View {
    let snapshot: BudgetSnapshot

    private var budgetAmount: Int64 { snapshot.budget.amountMinor }
    private var spent: Int64 { snapshot.spentAbsMinor }
    private var difference: Int64 { abs(budgetAmount - spent) }
    private var isOver: Bool { spent > budgetAmount }
    private var progress: Double {
        guard budgetAmount > 0 else { return 0 }
        return min(Double(spent) / Double(budgetAmount), 1)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Overall Budget")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textPrimary)
                Spacer()
                Text(snapshot.budget.timeFrame.title)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textSecondary)
            }

            BudgetSemicircleGauge(progress: progress, accent: isOver ? OrdinatioColor.expense : OrdinatioColor.income)
                .frame(height: 150)

            VStack(spacing: 6) {
                BudgetAmountText(
                    amountMinor: difference,
                    currencyCode: snapshot.budget.currencyCode,
                    highlight: isOver
                )
                Text("\(isOver ? "over" : "left") \(snapshot.budget.timeFrame.periodLabel)")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textSecondary)
            }

            HStack {
                Text(MoneyFormat.format(minorUnits: spent, currencyCode: snapshot.budget.currencyCode))
                Spacer()
                Text(MoneyFormat.format(minorUnits: budgetAmount, currencyCode: snapshot.budget.currencyCode))
            }
            .font(.system(.caption, design: .rounded).weight(.medium))
            .foregroundStyle(OrdinatioColor.textSecondary)
        }
        .padding(18)
        .budgetCardBackground(cornerRadius: 16)
    }
}

private struct BudgetGridCard: View {
    let snapshot: BudgetSnapshot

    private var title: String {
        snapshot.category?.name ?? "Category"
    }

    private var timeLeft: String {
        switch snapshot.budget.timeFrame {
        case .day:
            return "\(snapshot.period.hoursLeft()) hours left"
        default:
            return "\(snapshot.period.daysLeft()) days left"
        }
    }

    private var budgetAmount: Int64 { snapshot.budget.amountMinor }
    private var spent: Int64 { snapshot.spentAbsMinor }
    private var difference: Int64 { abs(budgetAmount - spent) }
    private var isOver: Bool { spent > budgetAmount }
    private var spentRatio: Double {
        guard budgetAmount > 0 else { return 0 }
        return min(Double(spent) / Double(budgetAmount), 1)
    }

    private var percentString: String {
        guard budgetAmount > 0 else { return "0%" }
        return "\(Int(round((Double(spent) / Double(budgetAmount)) * 100)))%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                OrdinatioIconTile(
                    symbolName: OrdinatioCategoryVisuals.symbolName(for: title),
                    color: OrdinatioCategoryVisuals.color(for: title),
                    size: 30
                )

                Spacer()

                Text(timeLeft)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textSecondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textPrimary)
                    .lineLimit(1)

                Text("\(percentString) spent".uppercased())
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(isOver ? OrdinatioColor.expense : OrdinatioColor.income)

                BudgetAmountText(
                    amountMinor: difference,
                    currencyCode: snapshot.budget.currencyCode,
                    highlight: isOver
                )

                Text("\(isOver ? "over" : "left") \(snapshot.budget.timeFrame.periodLabel)")
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .lineLimit(1)
            }

            BudgetProgressBar(
                progress: spentRatio,
                marker: snapshot.period.progress(),
                accent: isOver ? OrdinatioColor.expense : OrdinatioColor.income
            )
            .frame(height: 10)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .budgetCardBackground(cornerRadius: 16)
    }
}

private struct BudgetRowCard: View {
    let snapshot: BudgetSnapshot

    private var title: String {
        snapshot.category?.name ?? "Category"
    }

    private var subtitle: String {
        let percent = snapshot.budget.amountMinor > 0
            ? Int(round((Double(snapshot.spentAbsMinor) / Double(snapshot.budget.amountMinor)) * 100))
            : 0

        switch snapshot.budget.timeFrame {
        case .day:
            return "\(snapshot.period.hoursLeft())h left • \(percent)% spent"
        default:
            return "\(snapshot.period.daysLeft())d left • \(percent)% spent"
        }
    }

    private var budgetAmount: Int64 { snapshot.budget.amountMinor }
    private var difference: Int64 { abs(budgetAmount - snapshot.spentAbsMinor) }
    private var isOver: Bool { snapshot.spentAbsMinor > budgetAmount }

    var body: some View {
        HStack(spacing: 12) {
            OrdinatioIconTile(
                symbolName: OrdinatioCategoryVisuals.symbolName(for: title),
                color: OrdinatioCategoryVisuals.color(for: title),
                size: 36
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textPrimary)

                Text(subtitle)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                BudgetAmountText(
                    amountMinor: difference,
                    currencyCode: snapshot.budget.currencyCode,
                    highlight: isOver
                )

                Text("\(isOver ? "over" : "left") \(snapshot.budget.timeFrame.periodLabel)")
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textSecondary)
            }
        }
        .padding(12)
        .budgetCardBackground(cornerRadius: 16)
    }
}

private struct BudgetSemicircleGauge: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height * 2)
            let lineWidth: CGFloat = 20

            ZStack {
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(
                        OrdinatioColor.separator.opacity(0.35),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(180))

                Circle()
                    .trim(from: 0, to: 0.5 * progress)
                    .stroke(
                        accent,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(180))
            }
            .frame(width: size, height: size / 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .overlay(alignment: .top) {
                Text("OVERALL SPENT \(Int(round(progress * 100)))%")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .padding(.top, 4)
            }
        }
    }
}

private struct BudgetProgressBar: View {
    let progress: Double
    let marker: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)
            let clampedMarker = min(max(marker, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(OrdinatioColor.surfaceElevated)

                Capsule()
                    .fill(accent.opacity(0.9))
                    .frame(width: proxy.size.width * clampedProgress)
            }
            .overlay(alignment: .topLeading) {
                BudgetMarkerTriangle()
                    .fill(OrdinatioColor.textSecondary)
                    .frame(width: 12, height: 6)
                    .offset(x: (proxy.size.width * clampedMarker) - 6, y: -6)
            }
        }
    }
}

private struct BudgetMarkerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct BudgetAmountText: View {
    let amountMinor: Int64
    let currencyCode: String
    let highlight: Bool

    var body: some View {
        Text(MoneyFormat.format(minorUnits: amountMinor, currencyCode: currencyCode))
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .foregroundStyle(highlight ? OrdinatioColor.expense : OrdinatioColor.textPrimary)
    }
}

private extension View {
    func budgetCardBackground(cornerRadius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(OrdinatioColor.separator.opacity(0.5), lineWidth: 1)
                )
        }
    }
}

private struct DimeMainBudgetCard: View {
    let snapshot: BudgetSnapshot
    let soloBudget: Bool

    @Environment(\.colorScheme) private var colorScheme

    @State private var animatedRemaining: Double = 0

    private var budgetAmount: Int64 { snapshot.budget.amountMinor }
    private var spent: Int64 { snapshot.spentAbsMinor }
    private var difference: Int64 { abs(budgetAmount - spent) }
    private var isOver: Bool { spent >= budgetAmount }

    private var spentRatio: Double {
        guard budgetAmount > 0 else { return 0 }
        return Double(spent) / Double(budgetAmount)
    }

    private var remainingFraction: Double {
        guard budgetAmount > 0 else { return 0 }
        return max(min(1 - spentRatio, 1), 0)
    }

    private var spentPercentString: String {
        guard budgetAmount > 0 else { return "0%" }
        return "\(Int(round(spentRatio * 100)))%"
    }

    private var gaugeWidth: CGFloat {
        soloBudget ? UIScreen.main.bounds.width - 90 : 250
    }

    private var cardFill: Color {
        OrdinatioColor.separator.opacity(0.2)
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                DimeOverallGauge(
                    remainingFraction: animatedRemaining,
                    spentFraction: spentRatio,
                    markerFraction: snapshot.period.remainingFractionForGaugeMarker(),
                    showMarker: snapshot.budget.timeFrame != .day && spent < budgetAmount,
                    markerIsOnTrack: snapshot.period.remainingFractionForGaugeMarker() <= remainingFraction,
                    lineWidth: soloBudget ? 35 : 25
                )
                .frame(width: gaugeWidth, height: gaugeWidth / 2)

                DimeArcText(
                    text: "OVERALL SPENT: \(spentPercentString)",
                    radius: (gaugeWidth / 2) + 8,
                    font: UIFont.systemFont(ofSize: 13, weight: .medium),
                    color: OrdinatioColor.textSecondary
                )
                .frame(width: gaugeWidth, height: gaugeWidth / 2)

                VStack(spacing: -4) {
                    let internalWidth = soloBudget ? gaugeWidth - 90 : gaugeWidth - 60
                    BudgetMoneyView(
                        amountMinor: difference,
                        currencyCode: snapshot.budget.currencyCode,
                        red: isOver,
                        scale: 3
                    )
                    .frame(width: internalWidth)

                    Text("\(budgetAmount >= spent ? "left" : "over") \(snapshot.budget.timeFrame.periodLabel)")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }
            }

            HStack {
                Text(bottomNumberString(minor: spent))
                    .frame(width: 60, alignment: .leading)
                Spacer()
                Text(bottomNumberString(minor: budgetAmount))
                    .frame(width: 60, alignment: .trailing)
            }
            .font(.system(.caption2, design: .rounded).weight(.medium))
            .frame(width: gaugeWidth)
            .foregroundStyle(OrdinatioColor.textSecondary)
        }
        .padding(.bottom)
        .frame(width: gaugeWidth + 30, height: soloBudget ? 230 : 200, alignment: .bottom)
        .background(
            (soloBudget ? cardFill : OrdinatioColor.background),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onAppear {
            syncRemaining(animated: false)
        }
        .onChange(of: remainingFraction) { _ in
            syncRemaining(animated: true)
        }
    }

    private func syncRemaining(animated: Bool) {
        if spentRatio < 0.97, animated {
            withAnimation(.easeInOut(duration: 0.7)) {
                animatedRemaining = remainingFraction
            }
        } else {
            animatedRemaining = remainingFraction
        }
    }

    private func bottomNumberString(minor: Int64) -> String {
        let budgetMajor = majorValue(absMinor: abs(budgetAmount))
        let spentMajor = majorValue(absMinor: abs(spent))
        let showDecimals = budgetMajor < 1000 && spentMajor < 1000

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = false

        let fractionDigits = MoneyFormat.fractionDigits(for: snapshot.budget.currencyCode)
        formatter.minimumFractionDigits = showDecimals ? fractionDigits : 0
        formatter.maximumFractionDigits = showDecimals ? fractionDigits : 0

        let value = majorValue(absMinor: abs(minor))
        return formatter.string(from: NSNumber(value: showDecimals ? value : Double(Int(round(value))))) ?? "\(Int(round(value)))"
    }

    private func majorValue(absMinor: Int64) -> Double {
        let decimal = MoneyFormat.decimal(fromMinorUnits: absMinor, currencyCode: snapshot.budget.currencyCode)
        return (NSDecimalNumber(decimal: decimal)).doubleValue
    }
}

private struct DimeBudgetGridCard: View {
    let snapshot: BudgetSnapshot

    @Environment(\.colorScheme) private var colorScheme
    @State private var showBar = false

    private var title: String { snapshot.category?.name ?? "Category" }
    private var emoji: String { OrdinatioCategoryVisuals.emoji(for: title) }
    private var categoryColor: Color { OrdinatioCategoryVisuals.color(for: title) }

    private var budgetAmount: Int64 { snapshot.budget.amountMinor }
    private var spent: Int64 { snapshot.spentAbsMinor }
    private var difference: Int64 { abs(budgetAmount - spent) }
    private var isOver: Bool { spent >= budgetAmount }

    private var timeLeft: String {
        switch snapshot.budget.timeFrame {
        case .day:
            return "\(snapshot.period.hoursLeft()) hours left"
        default:
            return "\(snapshot.period.daysLeft()) days left"
        }
    }

    private var spentRatio: Double {
        guard budgetAmount > 0 else { return 0 }
        return Double(spent) / Double(budgetAmount)
    }

    private var remainingFraction: Double {
        guard budgetAmount > 0 else { return 0 }
        return max(min(1 - spentRatio, 1), 0)
    }

    private var spentPercentString: String {
        guard budgetAmount > 0 else { return "" }
        return "\(Int(round(spentRatio * 100)))%"
    }

    private var barTargetFraction: Double {
        snapshot.period.remainingFractionForBarMarker()
    }

    private var showBarTriangle: Bool {
        snapshot.budget.timeFrame != .day
            && spent < budgetAmount
            && barTargetFraction > 0
            && barTargetFraction < 0.95
    }

    private var barTriangleOnTrack: Bool {
        barTargetFraction <= remainingFraction
    }

    private var cardFill: Color {
        colorScheme == .dark ? OrdinatioColor.separator.opacity(0.2) : OrdinatioColor.separator.opacity(0.35)
    }

    private var cardWidth: CGFloat {
        (UIScreen.main.bounds.width - 75) / 2
    }

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 0.5) {
                    HStack(spacing: 4) {
                        Text(emoji)
                            .font(.system(.caption, design: .rounded))
                        Text(title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(OrdinatioColor.textPrimary)
                    }

                    Text(timeLeft)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 30)

            HStack {
                VStack(alignment: .leading, spacing: -2) {
                    if spent < budgetAmount {
                        Text("\(spentPercentString) SPENT")
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(OrdinatioColor.income)
                            .padding(.bottom, 5)
                    }

                    BudgetMoneyView(
                        amountMinor: difference,
                        currencyCode: snapshot.budget.currencyCode,
                        red: isOver,
                        scale: 2
                    )

                    Text("\(budgetAmount >= spent ? "left" : "over") \(snapshot.budget.timeFrame.periodLabel)")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                        .fill(OrdinatioColor.surfaceElevated)
                        .frame(width: proxy.size.width)

                    if spentRatio < 0.98 {
                        RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                            .fill(categoryColor)
                            .frame(width: proxy.size.width * (showBar ? remainingFraction : 0), alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topLeading) {
                    if showBarTriangle {
                        RoundedDownTriangle(cornerRadius: 1.3)
                            .fill(barTriangleOnTrack ? OrdinatioColor.darkBackground : OrdinatioColor.expense)
                            .frame(width: 14, height: 6.5)
                            .offset(x: (barTargetFraction * proxy.size.width) - 7, y: -3.5)
                    }
                }
            }
            .frame(height: 17.5)
    }
        .padding(15)
        .frame(width: cardWidth)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .onAppear {
            showBar = false
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                showBar = true
            }
        }
    }
}

private struct DimeBudgetRowCard: View {
    let snapshot: BudgetSnapshot
    var onEdit: () -> Void
    var onDeleteRequest: () -> Void
    var onDeleteImmediate: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var offset: CGFloat = 0
    @State private var deleted = false
    @GestureState private var isDragging = false

    private var title: String { snapshot.category?.name ?? "Category" }
    private var emoji: String { OrdinatioCategoryVisuals.emoji(for: title) }
    private var categoryColor: Color { OrdinatioCategoryVisuals.color(for: title) }

    private var budgetAmount: Int64 { snapshot.budget.amountMinor }
    private var spent: Int64 { snapshot.spentAbsMinor }
    private var difference: Int64 { abs(budgetAmount - spent) }
    private var isOver: Bool { spent >= budgetAmount }

    private var percentSpent: Int {
        guard budgetAmount > 0 else { return 0 }
        return Int(round((Double(spent) / Double(budgetAmount)) * 100))
    }

    private var timeLeft: String {
        switch snapshot.budget.timeFrame {
        case .day:
            return "\(snapshot.period.hoursLeft())h left"
        default:
            return "\(snapshot.period.daysLeft())d left"
        }
    }

    private var cardFill: Color {
        colorScheme == .dark ? OrdinatioColor.separator.opacity(0.2) : OrdinatioColor.separator.opacity(0.35)
    }

    private var deletePopup: Bool {
        abs(offset) > UIScreen.main.bounds.width * 0.15
    }

    private var deleteConfirm: Bool {
        abs(offset) > UIScreen.main.bounds.width * 0.50
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Image(systemName: "xmark")
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .foregroundStyle(deleteConfirm ? OrdinatioColor.expense : OrdinatioColor.textSecondary)
                .padding(5)
                .background(deleteConfirm ? OrdinatioColor.expense.opacity(0.23) : OrdinatioColor.surfaceElevated, in: Circle())
                .scaleEffect(deleteConfirm ? 1.1 : 1)
                .contentShape(Circle())
                .opacity(deleted ? 0 : 1)
                .padding(.horizontal, 10)
                .offset(x: 80)
                .offset(x: max(-80, offset))

            HStack {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white)

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(categoryColor.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(emoji)
                            .font(.system(size: 20))
                    }

                    VStack(alignment: .leading, spacing: -0.5) {
                        Text(title)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                            .foregroundStyle(OrdinatioColor.textPrimary)

                        Text("\(timeLeft) • \(percentSpent)% spent")
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .lineLimit(1)
                            .foregroundStyle(OrdinatioColor.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: -4) {
                    BudgetMoneyView(
                        amountMinor: difference,
                        currencyCode: snapshot.budget.currencyCode,
                        red: isOver,
                        scale: 1
                    )

                    Text("\(budgetAmount >= spent ? "left" : "over") \(snapshot.budget.timeFrame.periodLabel)")
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }
            }
            .padding(10)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .offset(x: offset)
        }
        .padding(.horizontal, 30)
        .onChange(of: deletePopup) { _ in
            if deletePopup {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .onChange(of: deleteConfirm) { _ in
            if deleteConfirm {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
        .animation(.default, value: deletePopup)
        .simultaneousGesture(
            DragGesture()
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    if value.translation.width < 0 {
                        offset = value.translation.width
                    }
                }
                .onEnded { _ in
                    if deleteConfirm {
                        deleted = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            offset -= UIScreen.main.bounds.width
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            onDeleteImmediate()
                        }
                    } else if deletePopup {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            offset = 0
                        }
                        onDeleteRequest()
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

private struct DimeOverallGauge: View {
    let remainingFraction: Double
    let spentFraction: Double
    let markerFraction: Double
    let showMarker: Bool
    let markerIsOnTrack: Bool
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width, proxy.size.height * 2)
            let center = CGPoint(x: width / 2, y: width / 2)

            ZStack {
                DimeDonutSemicircle(percent: 1, cornerRadius: 6.5, thickness: lineWidth)
                    .fill(OrdinatioColor.surfaceElevated)
                    .frame(width: width, height: width / 2)

                if spentFraction < 0.97 {
                    DimeDonutSemicircle(percent: remainingFraction, cornerRadius: 6.5, thickness: lineWidth)
                        .fill(OrdinatioColor.darkBackground)
                        .frame(width: width, height: width / 2)
                }
            }
            .frame(width: width, height: width / 2)
            .overlay(alignment: .top) {
                if showMarker && markerFraction > 0 {
                    let theta = CGFloat.pi + (CGFloat.pi * markerFraction)
                    let markerRadius = (width / 2) - 5
                    let markerPoint = CGPoint(
                        x: center.x + markerRadius * cos(theta),
                        y: center.y + markerRadius * sin(theta)
                    )

                    RoundedDownTriangle(cornerRadius: 2)
                        .fill(markerIsOnTrack ? OrdinatioColor.textSecondary : OrdinatioColor.expense)
                        .frame(width: 20, height: 10)
                        .rotationEffect(.degrees(markerRotationDegrees(markerFraction)), anchor: .bottom)
                        .position(x: markerPoint.x, y: markerPoint.y - 5)
                }
            }
        }
    }

    private func markerRotationDegrees(_ fraction: Double) -> Double {
        if fraction > 0.5 {
            return ((fraction - 0.5) / 0.5) * 90
        }
        if fraction < 0.5 {
            return -((0.5 - fraction) / 0.5) * 90
        }
        return 0
    }
}

private struct DimeDonutSemicircle: Shape {
    var percent: Double
    var cornerRadius: CGFloat
    var thickness: CGFloat

    var animatableData: Double {
        get { percent }
        set { percent = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clampedPercent = min(max(percent, 0), 1)
        guard clampedPercent > 0 else { return Path() }

        let outerRadius = rect.width / 2
        guard outerRadius > 0 else { return Path() }

        let thickness = min(max(thickness, 0), outerRadius)
        let innerRadius = outerRadius - thickness
        guard innerRadius > 0 else { return Path() }

        let cornerRadius = min(max(cornerRadius, 0), thickness / 2)
        guard cornerRadius > 0 else {
            return simpleSectorPath(in: rect, outerRadius: outerRadius, innerRadius: innerRadius, percent: clampedPercent)
        }

        let startAngle = CGFloat.pi
        let endAngle = CGFloat.pi + (CGFloat.pi * CGFloat(clampedPercent))
        let center = CGPoint(x: rect.midX, y: rect.maxY)

        let outerOffset = outerRadius - cornerRadius
        let innerOffset = innerRadius + cornerRadius
        guard outerOffset > 0 else {
            return simpleSectorPath(in: rect, outerRadius: outerRadius, innerRadius: innerRadius, percent: clampedPercent)
        }

        let outerRadial = sqrt(max((outerOffset * outerOffset) - (cornerRadius * cornerRadius), 0))
        let innerRadial = sqrt(max((innerOffset * innerOffset) - (cornerRadius * cornerRadius), 0))

        func unit(_ angle: CGFloat) -> CGPoint { CGPoint(x: cos(angle), y: sin(angle)) }
        func normal(_ angle: CGFloat) -> CGPoint { CGPoint(x: -sin(angle), y: cos(angle)) }
        func add(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
        func sub(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
        func mul(_ point: CGPoint, _ scalar: CGFloat) -> CGPoint { CGPoint(x: point.x * scalar, y: point.y * scalar) }
        func angle(of point: CGPoint) -> CGFloat { atan2(point.y, point.x) }

        let startSign: CGFloat = 1
        let endSign: CGFloat = -1

        let u0 = unit(startAngle)
        let n0 = normal(startAngle)
        let u1 = unit(endAngle)
        let n1 = normal(endAngle)

        let outerCenterStart = add(mul(u0, outerRadial), mul(n0, startSign * cornerRadius))
        let outerCenterEnd = add(mul(u1, outerRadial), mul(n1, endSign * cornerRadius))
        let innerCenterStart = add(mul(u0, innerRadial), mul(n0, startSign * cornerRadius))
        let innerCenterEnd = add(mul(u1, innerRadial), mul(n1, endSign * cornerRadius))

        let radialOuterStart = mul(u0, outerRadial)
        let radialOuterEnd = mul(u1, outerRadial)
        let radialInnerStart = mul(u0, innerRadial)
        let radialInnerEnd = mul(u1, innerRadial)

        let outerTangentStart = mul(outerCenterStart, outerRadius / outerOffset)
        let outerTangentEnd = mul(outerCenterEnd, outerRadius / outerOffset)
        let innerTangentStart = mul(innerCenterStart, innerRadius / innerOffset)
        let innerTangentEnd = mul(innerCenterEnd, innerRadius / innerOffset)

        func normalized(_ value: CGFloat) -> CGFloat {
            let twoPi = 2 * CGFloat.pi
            var v = value.truncatingRemainder(dividingBy: twoPi)
            if v < 0 { v += twoPi }
            return v
        }

        func positiveDelta(from start: CGFloat, to end: CGFloat) -> CGFloat {
            let s = normalized(start)
            let e = normalized(end)
            let d = e - s
            return d >= 0 ? d : d + 2 * CGFloat.pi
        }

        func segmentCount(delta: CGFloat, radius: CGFloat) -> Int {
            max(6, Int((delta * radius) / 10))
        }

        func addArc(
            to path: inout Path,
            center: CGPoint,
            radius: CGFloat,
            startAngle: CGFloat,
            endAngle: CGFloat,
            increasing: Bool
        ) {
            let delta: CGFloat
            if increasing {
                delta = positiveDelta(from: startAngle, to: endAngle)
            } else {
                delta = -positiveDelta(from: endAngle, to: startAngle)
            }

            let steps = segmentCount(delta: abs(delta), radius: radius)
            if steps <= 0 { return }

            for idx in 1 ... steps {
                let t = CGFloat(idx) / CGFloat(steps)
                let angle = startAngle + (delta * t)
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                path.addLine(to: point)
            }
        }

        func addShortestArc(
            to path: inout Path,
            center: CGPoint,
            radius: CGFloat,
            startAngle: CGFloat,
            endAngle: CGFloat
        ) {
            let inc = positiveDelta(from: startAngle, to: endAngle)
            addArc(to: &path, center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, increasing: inc <= .pi)
        }

        var path = Path()

        path.move(to: add(center, radialOuterStart))

        addShortestArc(
            to: &path,
            center: add(center, outerCenterStart),
            radius: cornerRadius,
            startAngle: angle(of: sub(radialOuterStart, outerCenterStart)),
            endAngle: angle(of: sub(outerTangentStart, outerCenterStart))
        )

        addArc(
            to: &path,
            center: center,
            radius: outerRadius,
            startAngle: angle(of: outerTangentStart),
            endAngle: angle(of: outerTangentEnd),
            increasing: true
        )

        addShortestArc(
            to: &path,
            center: add(center, outerCenterEnd),
            radius: cornerRadius,
            startAngle: angle(of: sub(outerTangentEnd, outerCenterEnd)),
            endAngle: angle(of: sub(radialOuterEnd, outerCenterEnd))
        )

        path.addLine(to: add(center, radialInnerEnd))

        addShortestArc(
            to: &path,
            center: add(center, innerCenterEnd),
            radius: cornerRadius,
            startAngle: angle(of: sub(radialInnerEnd, innerCenterEnd)),
            endAngle: angle(of: sub(innerTangentEnd, innerCenterEnd))
        )

        addArc(
            to: &path,
            center: center,
            radius: innerRadius,
            startAngle: angle(of: innerTangentEnd),
            endAngle: angle(of: innerTangentStart),
            increasing: false
        )

        addShortestArc(
            to: &path,
            center: add(center, innerCenterStart),
            radius: cornerRadius,
            startAngle: angle(of: sub(innerTangentStart, innerCenterStart)),
            endAngle: angle(of: sub(radialInnerStart, innerCenterStart))
        )

        path.addLine(to: add(center, radialOuterStart))
        path.closeSubpath()
        return path
    }

    private func simpleSectorPath(
        in rect: CGRect,
        outerRadius: CGFloat,
        innerRadius: CGFloat,
        percent: Double
    ) -> Path {
        let startAngle = CGFloat.pi
        let endAngle = CGFloat.pi + (CGFloat.pi * CGFloat(percent))
        let center = CGPoint(x: rect.midX, y: rect.maxY)

        func point(radius: CGFloat, angle: CGFloat) -> CGPoint {
            CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        }

        var path = Path()
        path.move(to: point(radius: outerRadius, angle: startAngle))
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: Angle(radians: Double(startAngle)),
            endAngle: Angle(radians: Double(endAngle)),
            clockwise: false
        )
        path.addLine(to: point(radius: innerRadius, angle: endAngle))
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: Angle(radians: Double(endAngle)),
            endAngle: Angle(radians: Double(startAngle)),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

private struct DimeArcText: View {
    let text: String
    let radius: CGFloat
    let font: UIFont
    let color: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height + 8)

            let characters = Array(text)
            let widths: [CGFloat] = characters.map { char in
                let attributes: [NSAttributedString.Key: Any] = [.font: font]
                return String(char).size(withAttributes: attributes).width
            }

            let totalWidth = widths.reduce(0, +)
            let totalAngle = totalWidth / radius

            var angle = -totalAngle / 2
            for (idx, char) in characters.enumerated() {
                let w = widths[idx]
                let halfAngle = (w / 2) / radius
                angle += halfAngle

                var copy = context
                copy.translateBy(x: center.x, y: center.y)
                copy.rotate(by: .radians(angle))
                copy.translateBy(x: 0, y: -radius)

                copy.draw(
                    Text(String(char))
                        .font(.system(size: font.pointSize, weight: .medium, design: .rounded))
                        .foregroundStyle(color),
                    at: .zero,
                    anchor: .center
                )

                angle += halfAngle
            }
        }
        .allowsHitTesting(false)
    }
}

private struct RoundedDownTriangle: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)

        let r = max(0, min(cornerRadius, min(rect.width, rect.height) / 2))

        func point(from: CGPoint, to: CGPoint, distance: CGFloat) -> CGPoint {
            let dx = to.x - from.x
            let dy = to.y - from.y
            let len = max(sqrt(dx * dx + dy * dy), 0.0001)
            let t = distance / len
            return CGPoint(x: from.x + dx * t, y: from.y + dy * t)
        }

        let start = point(from: topLeft, to: topRight, distance: r)
        let topRightEdge = point(from: topRight, to: topLeft, distance: r)
        let topRightDown = point(from: topRight, to: bottom, distance: r)
        let bottomRight = point(from: bottom, to: topRight, distance: r)
        let bottomLeft = point(from: bottom, to: topLeft, distance: r)
        let topLeftDown = point(from: topLeft, to: bottom, distance: r)

        var path = Path()
        path.move(to: start)
        path.addLine(to: topRightEdge)
        path.addQuadCurve(to: topRightDown, control: topRight)
        path.addLine(to: bottomRight)
        path.addQuadCurve(to: bottomLeft, control: bottom)
        path.addLine(to: topLeftDown)
        path.addQuadCurve(to: start, control: topLeft)
        path.closeSubpath()
        return path
    }
}

private struct BudgetMoneyView: View {
    let amountMinor: Int64
    let currencyCode: String
    let red: Bool
    let scale: Int

    private var fontSizes: (symbol: Font.TextStyle, amount: Font.TextStyle) {
        switch scale {
        case 1: return (.callout, .title3)
        case 2: return (.body, .title2)
        default: return (.title2, .largeTitle)
        }
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        return formatter.currencySymbol ?? currencyCode.uppercased()
    }

    private var formattedAmount: String {
        let absMinor = abs(amountMinor)
        let major = MoneyFormat.decimal(fromMinorUnits: absMinor, currencyCode: currencyCode)
        let value = NSDecimalNumber(decimal: major).doubleValue

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = false

        let fractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
        if fractionDigits == 0 {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        } else if value < 100 {
            formatter.minimumFractionDigits = fractionDigits
            formatter.maximumFractionDigits = fractionDigits
        } else {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }

        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 1.3) {
            Text(currencySymbol)
                .font(.system(fontSizes.symbol, design: .rounded).weight(.medium))
                .foregroundStyle(red ? OrdinatioColor.expense : OrdinatioColor.textSecondary)
            +
            Text(formattedAmount)
                .font(.system(fontSizes.amount, design: .rounded).weight(.medium))
                .foregroundStyle(red ? OrdinatioColor.expense : OrdinatioColor.textPrimary)
        }
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
}

private struct BudgetDeleteAlert: View {
    let snapshot: BudgetSnapshot
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var offset: CGFloat = 0

    private var title: String {
        if snapshot.budget.isOverall {
            return "Delete the overall budget?"
        }
        return "Delete the '\(snapshot.category?.name ?? "Category")' budget?"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            VStack(alignment: .leading, spacing: 1.5) {
                Text(title)
                    .font(.system(.title2, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textPrimary)

                Text("This action cannot be undone.")
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .padding(.bottom, 25)

                Button {
                    dismiss()
                    onDelete()
                } label: {
                    DeleteButton(text: "Delete", destructive: true)
                }
                .padding(.bottom, 8)

                Button {
                    withAnimation(.easeOut(duration: 0.7)) {
                        dismiss()
                    }
                } label: {
                    DeleteButton(text: "Cancel", destructive: false)
                }
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 13)
                    .fill(OrdinatioColor.background)
                    .shadow(color: colorScheme == .dark ? .clear : Color.black.opacity(0.15), radius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.10) : Color.clear, lineWidth: 1.3)
            )
            .offset(y: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height < 0 {
                            offset = gesture.translation.height / 3
                        } else {
                            offset = gesture.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 20 {
                            dismiss()
                        } else {
                            withAnimation {
                                offset = 0
                            }
                        }
                    }
            )
            .padding(.horizontal, 17)
            .padding(.bottom, 15)
        }
        .ignoresSafeArea()
        .background(BackgroundBlurView())
    }
}

private struct DeleteButton: View {
    let text: String
    let destructive: Bool

    var body: some View {
        Text(text)
            .font(.system(.title3, design: .rounded).weight(.semibold))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .foregroundStyle(destructive ? Color.white : OrdinatioColor.textPrimary)
            .background(
                destructive ? OrdinatioColor.expense : OrdinatioColor.surfaceElevated,
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
    }
}

private struct BackgroundBlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
