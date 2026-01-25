import Observation
import OrdinatioCore
import SwiftUI

struct BudgetDraft: Hashable {
    let budgetId: String?
    let isOverall: Bool
    let categoryId: String?
    let timeFrame: BudgetTimeFrame
    let startDate: Date
    let currencyCode: String
    let amountMinor: Int64
}

private struct InstructionHeadings {
    let title: String
    let subtitle: String
}

struct BudgetComposerView: View {
    let db: DatabaseClient
    let householdId: String
    let onSave: (BudgetDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Namespace private var animation

    @State private var model: BudgetComposerModel
    @State private var toastDismissTask: Task<Void, Never>?

    init(
        route: BudgetComposerRoute,
        db: DatabaseClient,
        householdId: String,
        categories: [OrdinatioCore.Category],
        existingCategoryBudgetIds: Set<String>,
        defaultCurrencyCode: String,
        onSave: @escaping (BudgetDraft) -> Void
    ) {
        self.db = db
        self.householdId = householdId
        self.onSave = onSave
        _model = State(
            initialValue: BudgetComposerModel(
                route: route,
                categories: categories,
                existingCategoryBudgetIds: existingCategoryBudgetIds,
                defaultCurrencyCode: defaultCurrencyCode
            )
        )
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            topBar

            instructionsHeader
                .frame(height: model.progress == 5 ? 130 : 170, alignment: .top)

            stageContent

            if model.progress < 5 {
                continueButton
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OrdinatioColor.background)
        .sensoryFeedback(trigger: model.sensoryFeedbackTrigger) {
            model.pendingSensoryFeedback
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .sheet(isPresented: $model.showingCategoryCreator) {
            CategoryEditorView(mode: .create) { name, iconIndex in
                createCategory(name: name, iconIndex: iconIndex)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.showToast)
        .onChange(of: model.showToast) { _, newValue in
            toastDismissTask?.cancel()
            guard newValue else { return }

            toastDismissTask = Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(2))
                    try Task.checkCancellation()
                } catch {
                    return
                }

                model.showToast = false
            }
        }
        .onDisappear {
            toastDismissTask?.cancel()
        }
    }
}

extension BudgetComposerView {
    fileprivate var showBackButton: Bool {
        model.progress > model.initialProgress
    }

    fileprivate var progressStepCount: Int {
        max(6 - model.initialProgress, 1)
    }

    fileprivate var progressStepIndex: Int {
        let step = max(model.progress - model.initialProgress + 1, 1)
        return min(step, progressStepCount)
    }

    fileprivate var currencyCode: String {
        model.defaultCurrencyCode.uppercased()
    }

    fileprivate var timeFrameString: String {
        switch model.budgetTimeFrame {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        }
    }

    fileprivate var instructions: [InstructionHeadings] {
        [
            InstructionHeadings(
                title: "Indicate budget type",
                subtitle:
                    "The overall budget tracks expenses across the board, while categorical budgets are tied to expenses of a particular type only."
            ),
            InstructionHeadings(
                title: "Select a category",
                subtitle: "Begin by linking this budget to an existing category."
            ),
            InstructionHeadings(
                title: "Choose a time frame",
                subtitle: "The budget will periodically refresh according to your preference."
            ),
            InstructionHeadings(
                title: "Pick a start date",
                subtitle: "Which day of the \(timeFrameString) do you want your budget to start from?"
            ),
            InstructionHeadings(
                title: "Set budget amount",
                subtitle: "Try your best to stay under this limit! Also, feel free to change this in the future."
            ),
        ]
    }

    fileprivate var availableCategoryOptions: [OrdinatioCore.Category] {
        model.categories.filter { category in
            guard !model.existingCategoryBudgetIds.contains(category.id) else {
                return category.id == model.selectedCategoryId
            }
            return true
        }
    }
}

extension BudgetComposerView {
    fileprivate var topBar: some View {
        HStack {
            Button {
                if showBackButton {
                    back()
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: showBackButton ? "chevron.left" : "xmark")
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .padding(8)
                    .background(OrdinatioColor.surfaceElevated, in: Circle())
            }
            .contentTransition(.symbolEffect(.replace.downUp.wholeSymbol))

            Spacer()

            BudgetStepProgress(
                currentStep: progressStepIndex,
                totalSteps: progressStepCount,
                accent: OrdinatioColor.actionBlue,
                track: OrdinatioColor.surfaceElevated
            )
            .frame(height: 24)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            if model.showToast {
                HStack(spacing: 6.5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.expense)

                    Text(model.toastMessage)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.expense)
                }
                .padding(8)
                .background(
                    OrdinatioColor.expense.opacity(0.23), in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .frame(width: 250)
            }
        }
        .padding(.bottom, 50)
        .animation(.easeInOut, value: showBackButton)
    }

    fileprivate var instructionsHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(instructions[model.progress - 1].title)
                    .foregroundStyle(OrdinatioColor.textPrimary)
                    .font(.system(.title2, design: .rounded).weight(.semibold))

                Spacer()
            }
            .frame(maxWidth: .infinity)

            Text(instructions[model.progress - 1].subtitle)
                .foregroundStyle(OrdinatioColor.textSecondary)
                .font(.system(.body, design: .rounded).weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    fileprivate var stageContent: some View {
        if model.progress == 1 {
            typeStage
        } else if model.progress == 2 {
            categoryStage
        } else if model.progress == 3 {
            timeFrameStage
        } else if model.progress == 4 {
            startDateStage
        } else if model.progress == 5 {
            amountStage
        }
    }
}

extension BudgetComposerView {
    fileprivate var typeStage: some View {
        VStack(spacing: 16) {
            BudgetTypeBlock(
                title: "Overall Budget",
                subtitle: "One limit across all spending.",
                symbol: "chart.pie.fill",
                accent: OrdinatioColor.actionBlue,
                selected: !model.categoryBudget
            ) {
                withAnimation(.easeIn(duration: 0.15)) {
                    model.categoryBudget = false
                }
            }

            BudgetTypeBlock(
                title: "Category Budget",
                subtitle: "A limit for one category.",
                symbol: "square.grid.2x2.fill",
                accent: OrdinatioColor.actionOrange,
                selected: model.categoryBudget
            ) {
                withAnimation(.easeIn(duration: 0.15)) {
                    model.categoryBudget = true
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    fileprivate var categoryStage: some View {
        let emptyState: (icon: String, message: String)? = {
            if availableCategoryOptions.isEmpty {
                return (icon: "tray.full.fill", message: "No remaining\ncategories.")
            }

            return nil
        }()

        return VStack(spacing: 12) {
            if let emptyState {
                VStack(spacing: 12) {
                    Image(systemName: emptyState.icon)
                        .font(.system(.largeTitle, design: .rounded))
                        .foregroundStyle(OrdinatioColor.textSecondary.opacity(0.7))
                        .padding(.top, 20)

                    Text(emptyState.message)
                        .font(.system(.title3, design: .rounded).weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(OrdinatioColor.textSecondary.opacity(0.7))
                        .padding(.bottom, 20)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    FlowLayout(spacing: 10) {
                        ForEach(availableCategoryOptions) { category in
                            BudgetCategoryChip(
                                category: category,
                                selected: model.selectedCategoryId == category.id,
                                dimmed: model.selectedCategoryId != nil && model.selectedCategoryId != category.id
                            ) {
                                if model.selectedCategoryId == category.id {
                                    model.selectedCategoryId = nil
                                } else {
                                    model.selectedCategoryId = category.id
                                }
                            }
                        }
                    }
                    .padding(15)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)

            categoryAddButton
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    fileprivate var categoryAddButton: some View {
        Button {
            model.showingCategoryCreator = true
        } label: {
            Label("Create Category", systemImage: "plus")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(OrdinatioColor.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(LiquidGlassCapsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create Category")
    }

    fileprivate var timeFrameStage: some View {
        VStack {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(BudgetTimeFrame.allCases, id: \.self) { frame in
                    BudgetTypeRow(
                        title: timeFrameTitle(frame), selected: model.budgetTimeFrame == frame, animation: animation
                    ) {
                        withAnimation(.easeIn(duration: 0.15)) {
                            model.budgetTimeFrame = frame
                        }
                    }
                }
            }
            .modifier(BudgetPickerStyle(colorScheme: colorScheme))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    fileprivate var startDateStage: some View {
        @Bindable var model = model

        return VStack {
            switch model.budgetTimeFrame {
            case .day:
                EmptyView()
            case .week:
                ScrollView(showsIndicators: false) {
                    ScrollViewReader { value in
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(weekdayOptions, id: \.value) { option in
                                BudgetTypeRow(
                                    title: option.label,
                                    selected: model.chosenDayWeek == option.value,
                                    animation: animation
                                ) {
                                    withAnimation(.easeIn(duration: 0.15)) {
                                        model.chosenDayWeek = option.value
                                    }
                                }
                                .id(option.value)
                            }
                        }
                        .onAppear {
                            value.scrollTo(model.chosenDayWeek)
                        }
                    }
                }
                .modifier(BudgetPickerStyle(colorScheme: colorScheme))
                .frame(height: 250)
            case .month:
                ScrollView(showsIndicators: false) {
                    ScrollViewReader { value in
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(1..<29) { day in
                                BudgetTypeRow(
                                    title: monthStartLabel(day),
                                    selected: model.chosenDayMonth == day,
                                    animation: animation
                                ) {
                                    withAnimation(.easeIn(duration: 0.15)) {
                                        model.chosenDayMonth = day
                                    }
                                }
                                .id(day)
                            }
                        }
                        .onAppear {
                            value.scrollTo(model.chosenDayMonth)
                        }
                    }
                }
                .modifier(BudgetPickerStyle(colorScheme: colorScheme))
                .frame(height: 250)
            case .year:
                DatePicker(
                    "Date",
                    selection: $model.chosenDayYear,
                    in: oneYearAgo...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(OrdinatioColor.expense)
                .padding(.horizontal, 5)
                .modifier(BudgetPickerStyle(colorScheme: colorScheme))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    fileprivate var amountStage: some View {
        @Bindable var model = model

        return VStack(spacing: 10) {
            BudgetNumberPadTextView(amountMinor: model.amountMinor, currencyCode: currencyCode)

            if model.budgetTimeFrame != .day && model.amountMinor > 0 {
                Text(amountPerDayString())
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .padding(4)
                    .padding(.horizontal, 7)
                    .background(OrdinatioColor.surfaceElevated, in: Capsule())
            }

            Spacer()

            BudgetNumberPad(
                amountMinor: $model.amountMinor,
                canSubmit: canSubmitAmount,
                onSubmit: submit
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension BudgetComposerView {
    fileprivate func playSensoryFeedback(_ feedback: SensoryFeedback) {
        model.pendingSensoryFeedback = feedback
        model.sensoryFeedbackTrigger += 1
    }

    fileprivate var continueButton: some View {
        let missingCategory = model.progress == 2 && model.selectedCategoryId == nil

        return Button {
            if missingCategory {
                model.toastMessage = "Missing Category"
                model.showToast = true
                playSensoryFeedback(.error)
                return
            }

            playSensoryFeedback(.impact(weight: .light, intensity: 1))
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.8)) {
                advance()
            }
        } label: {
            Text("Continue")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .foregroundStyle(missingCategory ? OrdinatioColor.textSecondary : OrdinatioColor.lightIcon)
                .background(
                    missingCategory ? Color.clear : OrdinatioColor.darkBackground,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay {
                    if missingCategory {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(OrdinatioColor.separator, lineWidth: 1.3)
                    }
                }
        }
        .buttonStyle(BouncyButtonStyle(duration: 0.2, scale: 0.8))
        .accessibilityIdentifier("BudgetComposerContinue")
    }
}

extension BudgetComposerView {
    fileprivate static let ordinalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        formatter.locale = .current
        return formatter
    }()

    fileprivate var canSubmitAmount: Bool {
        model.amountMinor > 0 && (!model.categoryBudget || model.selectedCategoryId != nil)
    }

    fileprivate var oneYearAgo: Date {
        Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    }

    fileprivate var weekdayOptions: [(label: String, value: Int)] {
        let names = Calendar.current.weekdaySymbols
        return names.enumerated().map { idx, label in
            (label: label, value: idx + 1)
        }
    }

    fileprivate func timeFrameTitle(_ frame: BudgetTimeFrame) -> String {
        switch frame {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    fileprivate func monthStartLabel(_ day: Int) -> String {
        if day == 1 { return "Start of month" }
        let ordinal = (Self.ordinalFormatter.string(from: day as NSNumber) ?? "\(day)")
            .replacingOccurrences(of: ".", with: "")
        return "\(ordinal) of month"
    }

    fileprivate func amountPerDayString() -> String {
        let decimal = MoneyFormat.decimal(fromMinorUnits: model.amountMinor, currencyCode: currencyCode)
        let divisor: Decimal

        switch model.budgetTimeFrame {
        case .week: divisor = 7
        case .month: divisor = 30
        case .year: divisor = 365
        case .day: divisor = 1
        }

        let average = decimal / divisor

        let formatted = average.formatted(
            .currency(code: currencyCode)
                .precision(.fractionLength(0))
        )
        return "~\(formatted) /day"
    }

    fileprivate func advance() {
        if model.progress >= 5 { return }

        if model.progress == 1 {
            model.progress += model.categoryBudget ? 1 : 2
        } else if model.progress == 3 {
            model.progress += model.budgetTimeFrame == .day ? 2 : 1
        } else {
            model.progress += 1
        }
    }

    fileprivate func back() {
        if model.progress == 3 && !model.categoryBudget {
            model.progress -= 2
        } else if model.progress == 5 && model.budgetTimeFrame == .day {
            model.progress -= 2
        } else if model.progress > model.initialProgress {
            model.progress -= 1
        }
    }

    fileprivate func submit() {
        if model.amountMinor == 0 {
            model.toastMessage = "Missing Amount"
            model.showToast = true
            playSensoryFeedback(.error)
            return
        }

        if model.categoryBudget && model.selectedCategoryId == nil {
            model.toastMessage = "Missing Category"
            model.showToast = true
            playSensoryFeedback(.error)
            return
        }

        playSensoryFeedback(.impact(weight: .light, intensity: 1))

        let startDate = computedStartDate()

        onSave(
            BudgetDraft(
                budgetId: nil,
                isOverall: !model.categoryBudget,
                categoryId: model.categoryBudget ? model.selectedCategoryId : nil,
                timeFrame: model.budgetTimeFrame,
                startDate: startDate,
                currencyCode: currencyCode.uppercased(),
                amountMinor: model.amountMinor
            )
        )
        dismiss()
    }

    fileprivate func computedStartDate(referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let reference = calendar.startOfDay(for: referenceDate)

        switch model.budgetTimeFrame {
        case .day:
            return reference
        case .week:
            let match = calendar.nextDate(
                after: reference,
                matching: DateComponents(weekday: model.chosenDayWeek),
                matchingPolicy: .nextTime,
                direction: .backward
            )
            return calendar.startOfDay(for: match ?? reference)
        case .month:
            let clampedDay = min(max(model.chosenDayMonth, 1), 28)
            let components = calendar.dateComponents([.year, .month], from: reference)
            let year = components.year ?? 1
            let month = components.month ?? 1
            let candidate = calendar.date(from: DateComponents(year: year, month: month, day: clampedDay)) ?? reference
            if candidate <= reference {
                return calendar.startOfDay(for: candidate)
            }
            let previous = calendar.date(byAdding: .month, value: -1, to: candidate) ?? candidate
            let prevComponents = calendar.dateComponents([.year, .month], from: previous)
            let prevYear = prevComponents.year ?? year
            let prevMonth = prevComponents.month ?? month
            let prevCandidate =
                calendar.date(from: DateComponents(year: prevYear, month: prevMonth, day: clampedDay)) ?? previous
            return calendar.startOfDay(for: prevCandidate)
        case .year:
            let year = calendar.component(.year, from: reference)
            let month = calendar.component(.month, from: model.chosenDayYear)
            let day = min(max(calendar.component(.day, from: model.chosenDayYear), 1), 28)
            let candidate = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? reference
            if candidate <= reference {
                return calendar.startOfDay(for: candidate)
            }
            let prev = calendar.date(byAdding: .year, value: -1, to: candidate) ?? candidate
            return calendar.startOfDay(for: prev)
        }
    }

    fileprivate func createCategory(name: String, iconIndex: Int?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task { @MainActor in
            do {
                let created = try await db.createCategory(
                    householdId: householdId,
                    kind: .expense,
                    name: trimmed,
                    iconIndex: iconIndex
                )
                model.categories.append(created)
                model.categories.sort { $0.sortOrder < $1.sortOrder }
            } catch {
                model.toastMessage = "Couldn't create category"
                model.showToast = true
                playSensoryFeedback(.error)
            }
        }
    }
}
