import SwiftUI
import OrdinatioCore

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
    let route: BudgetComposerRoute
    let database: AppDatabase
    let householdId: String
    @State private var categories: [OrdinatioCore.Category]
    let existingCategoryBudgetIds: Set<String>
    let defaultCurrencyCode: String
    var onSave: (BudgetDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Namespace private var animation

    @State private var progress: Int
    private let initialProgress: Int

    @State private var categoryBudget: Bool
    @State private var selectedCategoryId: String?

    @State private var budgetTimeFrame: BudgetTimeFrame
    @State private var chosenDayWeek: Int
    @State private var chosenDayMonth: Int
    @State private var chosenDayYear: Date

    @State private var amountMinor: Int64

    @State private var showToast = false
    @State private var toastMessage = "Missing Category"
    @State private var showingCategoryCreator = false

    @State private var sensoryFeedbackTrigger = 0
    @State private var pendingSensoryFeedback: SensoryFeedback?

    init(
        route: BudgetComposerRoute,
        database: AppDatabase,
        householdId: String,
        categories: [OrdinatioCore.Category],
        existingCategoryBudgetIds: Set<String>,
        defaultCurrencyCode: String,
        onSave: @escaping (BudgetDraft) -> Void
    ) {
        self.route = route
        self.database = database
        self.householdId = householdId
        _categories = State(initialValue: categories)
        self.existingCategoryBudgetIds = existingCategoryBudgetIds
        self.defaultCurrencyCode = defaultCurrencyCode
        self.onSave = onSave

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let initialProgress = route.overallExists ? 2 : 1
        self.initialProgress = initialProgress
        _progress = State(initialValue: initialProgress)
        _categoryBudget = State(initialValue: route.overallExists ? true : false)
        _selectedCategoryId = State(initialValue: nil)
        _budgetTimeFrame = State(initialValue: .week)
        _chosenDayWeek = State(initialValue: calendar.component(.weekday, from: today))
        _chosenDayMonth = State(initialValue: 1)
        _chosenDayYear = State(initialValue: today)
        _amountMinor = State(initialValue: 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            instructionsHeader
                .frame(height: progress == 5 ? 130 : 170, alignment: .top)

            stageContent

            if progress < 5 {
                continueButton
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(OrdinatioColor.background)
        .sensoryFeedback(trigger: sensoryFeedbackTrigger) {
            pendingSensoryFeedback
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .sheet(isPresented: $showingCategoryCreator) {
            CategoryEditorView(mode: .create) { name in
                createCategory(name: name)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showToast)
        .onChange(of: showToast) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showToast = false
                }
            }
        }
    }
}

private extension BudgetComposerView {
    var showBackButton: Bool {
        progress > initialProgress
    }

    var progressStepCount: Int {
        max(6 - initialProgress, 1)
    }

    var progressStepIndex: Int {
        let step = max(progress - initialProgress + 1, 1)
        return min(step, progressStepCount)
    }

    var currencyCode: String {
        defaultCurrencyCode.uppercased()
    }

    var timeFrameString: String {
        switch budgetTimeFrame {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        }
    }

    var instructions: [InstructionHeadings] {
        [
            InstructionHeadings(
                title: "Indicate budget type",
                subtitle: "The overall budget tracks expenses across the board, while categorical budgets are tied to expenses of a particular type only."
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

    var availableCategoryOptions: [OrdinatioCore.Category] {
        categories.filter { category in
            guard !existingCategoryBudgetIds.contains(category.id) else {
                return category.id == selectedCategoryId
            }
            return true
        }
    }
}

private extension BudgetComposerView {
    var topBar: some View {
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
            if showToast {
                HStack(spacing: 6.5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.expense)

                    Text(toastMessage)
                        .font(.system(.callout, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.expense)
                }
                .padding(8)
                .background(OrdinatioColor.expense.opacity(0.23), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
                .frame(width: 250)
            }
        }
        .padding(.bottom, 50)
        .animation(.easeInOut, value: showBackButton)
    }

    var instructionsHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(instructions[progress - 1].title)
                    .foregroundStyle(OrdinatioColor.textPrimary)
                    .font(.system(.title2, design: .rounded).weight(.semibold))

                Spacer()
            }
            .frame(maxWidth: .infinity)

            Text(instructions[progress - 1].subtitle)
                .foregroundStyle(OrdinatioColor.textSecondary)
                .font(.system(.body, design: .rounded).weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    var stageContent: some View {
        if progress == 1 {
            typeStage
        } else if progress == 2 {
            categoryStage
        } else if progress == 3 {
            timeFrameStage
        } else if progress == 4 {
            startDateStage
        } else if progress == 5 {
            amountStage
        }
    }
}

private extension BudgetComposerView {
    var typeStage: some View {
        VStack(spacing: 16) {
            BudgetTypeBlock(
                title: "Overall Budget",
                subtitle: "One limit across all spending.",
                symbol: "chart.pie.fill",
                accent: OrdinatioColor.actionBlue,
                selected: !categoryBudget
            ) {
                withAnimation(.easeIn(duration: 0.15)) {
                    categoryBudget = false
                }
            }

            BudgetTypeBlock(
                title: "Category Budget",
                subtitle: "A limit for one category.",
                symbol: "square.grid.2x2.fill",
                accent: OrdinatioColor.actionOrange,
                selected: categoryBudget
            ) {
                withAnimation(.easeIn(duration: 0.15)) {
                    categoryBudget = true
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var categoryStage: some View {
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
                                selected: selectedCategoryId == category.id,
                                dimmed: selectedCategoryId != nil && selectedCategoryId != category.id
                            ) {
                                if selectedCategoryId == category.id {
                                    selectedCategoryId = nil
                                } else {
                                    selectedCategoryId = category.id
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

    var categoryAddButton: some View {
        Button {
            showingCategoryCreator = true
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

    var timeFrameStage: some View {
        VStack {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(BudgetTimeFrame.allCases, id: \.self) { frame in
                    BudgetTypeRow(title: timeFrameTitle(frame), selected: budgetTimeFrame == frame, animation: animation) {
                        withAnimation(.easeIn(duration: 0.15)) {
                            budgetTimeFrame = frame
                        }
                    }
                }
            }
            .modifier(BudgetPickerStyle(colorScheme: colorScheme))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var startDateStage: some View {
        VStack {
            switch budgetTimeFrame {
            case .day:
                EmptyView()
            case .week:
                ScrollView(showsIndicators: false) {
                    ScrollViewReader { value in
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(weekdayOptions, id: \.value) { option in
                                BudgetTypeRow(title: option.label, selected: chosenDayWeek == option.value, animation: animation) {
                                    withAnimation(.easeIn(duration: 0.15)) {
                                        chosenDayWeek = option.value
                                    }
                                }
                                .id(option.value)
                            }
                        }
                        .onAppear {
                            value.scrollTo(chosenDayWeek)
                        }
                    }
                }
                .modifier(BudgetPickerStyle(colorScheme: colorScheme))
                .frame(height: 250)
            case .month:
                ScrollView(showsIndicators: false) {
                    ScrollViewReader { value in
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(1 ..< 29) { day in
                                BudgetTypeRow(title: monthStartLabel(day), selected: chosenDayMonth == day, animation: animation) {
                                    withAnimation(.easeIn(duration: 0.15)) {
                                        chosenDayMonth = day
                                    }
                                }
                                .id(day)
                            }
                        }
                        .onAppear {
                            value.scrollTo(chosenDayMonth)
                        }
                    }
                }
                .modifier(BudgetPickerStyle(colorScheme: colorScheme))
                .frame(height: 250)
            case .year:
                DatePicker(
                    "Date",
                    selection: $chosenDayYear,
                    in: oneYearAgo ... Date(),
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

    var amountStage: some View {
        VStack(spacing: 10) {
            BudgetNumberPadTextView(amountMinor: amountMinor, currencyCode: currencyCode)

            if budgetTimeFrame != .day && amountMinor > 0 {
                Text(amountPerDayString())
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .padding(4)
                    .padding(.horizontal, 7)
                    .background(OrdinatioColor.surfaceElevated, in: Capsule())
            }

            Spacer()

            BudgetNumberPad(
                amountMinor: $amountMinor,
                canSubmit: canSubmitAmount,
                onSubmit: submit
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private extension BudgetComposerView {
    func playSensoryFeedback(_ feedback: SensoryFeedback) {
        pendingSensoryFeedback = feedback
        sensoryFeedbackTrigger += 1
    }

    var continueButton: some View {
        let missingCategory = progress == 2 && selectedCategoryId == nil

        return Button {
            if missingCategory {
                toastMessage = "Missing Category"
                showToast = true
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
    }
}

private extension BudgetComposerView {
    var canSubmitAmount: Bool {
        amountMinor > 0 && (!categoryBudget || selectedCategoryId != nil)
    }

    var oneYearAgo: Date {
        Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    }

    var weekdayOptions: [(label: String, value: Int)] {
        let formatter = DateFormatter()
        let names = formatter.weekdaySymbols ?? []
        return names.enumerated().map { idx, label in
            (label: label, value: idx + 1)
        }
    }

    func timeFrameTitle(_ frame: BudgetTimeFrame) -> String {
        switch frame {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        }
    }

    func monthStartLabel(_ day: Int) -> String {
        if day == 1 { return "Start of month" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        let ordinal = (formatter.string(from: day as NSNumber) ?? "\(day)")
            .replacingOccurrences(of: ".", with: "")
        return "\(ordinal) of month"
    }

    func amountPerDayString() -> String {
        let decimal = MoneyFormat.decimal(fromMinorUnits: amountMinor, currencyCode: currencyCode)
        let divisor: Decimal

        switch budgetTimeFrame {
        case .week: divisor = 7
        case .month: divisor = 30
        case .year: divisor = 365
        case .day: divisor = 1
        }

        let average = decimal / divisor

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        formatter.maximumFractionDigits = 0

        let formatted = formatter.string(from: NSDecimalNumber(decimal: average)) ?? "0"
        return "~\(formatted) /day"
    }

    func advance() {
        if progress >= 5 { return }

        if progress == 1 {
            progress += categoryBudget ? 1 : 2
        } else if progress == 3 {
            progress += budgetTimeFrame == .day ? 2 : 1
        } else {
            progress += 1
        }
    }

    func back() {
        if progress == 3 && !categoryBudget {
            progress -= 2
        } else if progress == 5 && budgetTimeFrame == .day {
            progress -= 2
        } else if progress > initialProgress {
            progress -= 1
        }
    }

    func submit() {
        if amountMinor == 0 {
            toastMessage = "Missing Amount"
            showToast = true
            playSensoryFeedback(.error)
            return
        }

        if categoryBudget && selectedCategoryId == nil {
            toastMessage = "Missing Category"
            showToast = true
            playSensoryFeedback(.error)
            return
        }

        playSensoryFeedback(.impact(weight: .light, intensity: 1))

        let startDate = computedStartDate()

        onSave(
            BudgetDraft(
                budgetId: nil,
                isOverall: !categoryBudget,
                categoryId: categoryBudget ? selectedCategoryId : nil,
                timeFrame: budgetTimeFrame,
                startDate: startDate,
                currencyCode: currencyCode.uppercased(),
                amountMinor: amountMinor
            )
        )
        dismiss()
    }

    func computedStartDate(referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        let reference = calendar.startOfDay(for: referenceDate)

        switch budgetTimeFrame {
        case .day:
            return reference
        case .week:
            let match = calendar.nextDate(
                after: reference,
                matching: DateComponents(weekday: chosenDayWeek),
                matchingPolicy: .nextTime,
                direction: .backward
            )
            return calendar.startOfDay(for: match ?? reference)
        case .month:
            let clampedDay = min(max(chosenDayMonth, 1), 28)
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
            let prevCandidate = calendar.date(from: DateComponents(year: prevYear, month: prevMonth, day: clampedDay)) ?? previous
            return calendar.startOfDay(for: prevCandidate)
        case .year:
            let year = calendar.component(.year, from: reference)
            let month = calendar.component(.month, from: chosenDayYear)
            let day = min(max(calendar.component(.day, from: chosenDayYear), 1), 28)
            let candidate = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? reference
            if candidate <= reference {
                return calendar.startOfDay(for: candidate)
            }
            let prev = calendar.date(byAdding: .year, value: -1, to: candidate) ?? candidate
            return calendar.startOfDay(for: prev)
        }
    }

    func createCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            var created: OrdinatioCore.Category?
            try database.write { db in
                created = try CategoryRepository.createCategory(in: db, householdId: householdId, name: trimmed)
            }
            if let created {
                categories.append(created)
                categories.sort { $0.sortOrder < $1.sortOrder }
            }
        } catch {
            toastMessage = "Couldn't create category"
            showToast = true
            playSensoryFeedback(.error)
        }
    }
}

private struct BudgetTypeRow: View {
    let title: String
    let selected: Bool
    let animation: Namespace.ID
    var onTap: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(.callout, design: .rounded).weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(OrdinatioColor.textPrimary)
        .font(.system(.title3, design: .rounded).weight(.medium))
        .padding(8)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 6)
                    .fill(OrdinatioColor.surfaceElevated)
                    .matchedGeometryEffect(id: "budget_picker", in: animation)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

private struct BudgetTypeBlock: View {
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color
    let selected: Bool
    var onTap: () -> Void

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(selected ? 0.2 : 0.12))

                    Image(systemName: symbol)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textPrimary)

                    Text(subtitle)
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(selected ? accent : OrdinatioColor.textSecondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .background(cardShape.fill(OrdinatioColor.surfaceElevated))
            .overlay {
                cardShape
                    .strokeBorder(
                        selected ? accent.opacity(0.6) : OrdinatioColor.separator,
                        lineWidth: selected ? 2 : 1
                    )
            }
            .overlay {
                if selected {
                    cardShape
                        .fill(accent.opacity(0.08))
                }
            }
            .contentShape(cardShape)
        }
        .buttonStyle(BouncyButtonStyle(duration: 0.2, scale: 0.98))
    }
}

private struct BudgetCategoryChip: View {
    let category: OrdinatioCore.Category
    let selected: Bool
    let dimmed: Bool
    var onTap: () -> Void

    private var name: String { category.name }
    private var emoji: String { OrdinatioCategoryVisuals.emoji(for: name) }
    private var color: Color { OrdinatioCategoryVisuals.color(for: name) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Text(emoji)
                    .font(.system(.subheadline, design: .rounded))
                Text(name)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? color : OrdinatioColor.textPrimary)
            .background(selected ? color.opacity(0.35) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                if !selected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(OrdinatioColor.separator, lineWidth: 1.5)
                }
            }
            .opacity(dimmed ? 0.4 : 1)
        }
        .buttonStyle(BouncyButtonStyle(duration: 0.2, scale: 0.8))
    }
}

private struct BudgetPickerStyle: ViewModifier {
    var colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(OrdinatioColor.background)
                    .shadow(color: colorScheme == .light ? OrdinatioColor.separator : Color.clear, radius: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(colorScheme == .light ? Color.clear : OrdinatioColor.separator.opacity(0.4), lineWidth: 1.3)
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 30)
    }
}

private struct BudgetStepProgress: View {
    let currentStep: Int
    let totalSteps: Int
    let accent: Color
    let track: Color

    private var clampedTotal: Int {
        max(totalSteps, 1)
    }

    private var clampedCurrent: Int {
        min(max(currentStep, 1), clampedTotal)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1 ... clampedTotal, id: \.self) { step in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(step <= clampedCurrent ? accent : track.opacity(0.6))

                        if clampedTotal > 1 {
                            Text("\(step)")
                                .font(.system(.caption2, design: .rounded).weight(.semibold))
                                .foregroundStyle(step <= clampedCurrent ? OrdinatioColor.lightIcon : OrdinatioColor.textSecondary)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .overlay {
                        Circle()
                            .strokeBorder(OrdinatioColor.separator, lineWidth: step <= clampedCurrent ? 0 : 1)
                    }

                    if step < clampedTotal {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(step < clampedCurrent ? accent.opacity(0.8) : track.opacity(0.5))
                            .frame(width: 14, height: 3)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}

private struct BudgetNumberPadTextView: View {
    let amountMinor: Int64
    let currencyCode: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        return formatter.currencySymbol ?? currencyCode.uppercased()
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(currencySymbol)
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(OrdinatioColor.textSecondary)

            Text(amountString)
                .font(.system(size: amountFontSize, weight: .regular, design: .rounded))
                .foregroundStyle(OrdinatioColor.textPrimary)
        }
        .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }

    private var amountString: String {
        let decimal = MoneyFormat.decimal(fromMinorUnits: abs(amountMinor), currencyCode: currencyCode)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
        formatter.maximumFractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "0"
    }

    private var amountFontSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall:
            return 46
        case .small:
            return 47
        case .medium:
            return 48
        case .large:
            return 50
        case .xLarge:
            return 56
        case .xxLarge:
            return 58
        case .xxxLarge:
            return 62
        default:
            return 50
        }
    }
}

private struct BudgetNumberPad: View {
    @Binding var amountMinor: Int64
    let canSubmit: Bool
    var onSubmit: () -> Void

    private let numPadNumbers = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

    var body: some View {
        GeometryReader { proxy in
            let hSpacing = proxy.size.width * 0.05
            let vSpacing = proxy.size.height * 0.04

            let buttonWidth = proxy.size.width * 0.3
            let buttonHeight = proxy.size.height * 0.22

            VStack(spacing: vSpacing) {
                ForEach(numPadNumbers, id: \.self) { row in
                    HStack(spacing: hSpacing) {
                        ForEach(row, id: \.self) { digit in
                            digitButton(digit, width: buttonWidth, height: buttonHeight)
                        }
                    }
                }

                HStack(spacing: hSpacing) {
                    deleteButton(width: buttonWidth, height: buttonHeight)

                    digitButton(0, width: buttonWidth, height: buttonHeight)

                    submitButton(width: buttonWidth, height: buttonHeight)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.bottom, 15)
    }

    private func digitButton(_ digit: Int, width: CGFloat, height: CGFloat) -> some View {
        Button {
            appendDigit(digit)
        } label: {
            Text("\(digit)")
                .font(.system(size: 34, weight: .regular, design: .rounded))
                .frame(width: width, height: height)
                .background(OrdinatioColor.surfaceElevated)
                .foregroundStyle(OrdinatioColor.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(NumPadButtonStyle())
    }

    private func deleteButton(width: CGFloat, height: CGFloat) -> some View {
        Button {
            deleteDigit()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .frame(width: width, height: height)
                .background(OrdinatioColor.darkBackground)
                .foregroundStyle(OrdinatioColor.lightIcon)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(NumPadButtonStyle())
        .accessibilityLabel("Backspace")
    }

    private func submitButton(width: CGFloat, height: CGFloat) -> some View {
        Button {
            onSubmit()
        } label: {
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .symbolEffect(.bounce.up.byLayer, value: canSubmit)
                .frame(width: width, height: height)
                .foregroundStyle(OrdinatioColor.lightIcon)
                .background(OrdinatioColor.darkBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(NumPadButtonStyle())
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.6)
    }

    private func appendDigit(_ digit: Int) {
        guard (0...9).contains(digit) else { return }
        if amountMinor > (Int64.max / 10) {
            return
        }
        amountMinor = (amountMinor * 10) + Int64(digit)
    }

    private func deleteDigit() {
        amountMinor /= 10
    }
}

private struct NumPadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

private struct BouncyButtonStyle: ButtonStyle {
    let duration: Double
    let scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: duration), value: configuration.isPressed)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                totalHeight += rowHeight + spacing
                currentX = 0
                rowHeight = 0
            }
            currentX += size.width + (currentX > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }

        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
