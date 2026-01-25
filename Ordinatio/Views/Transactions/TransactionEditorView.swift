import Observation
import OrdinatioCore
import SwiftUI
import UIKit

enum TransactionEditorMode: Hashable {
    case create
    case edit(TransactionListRow)
}

struct TransactionEditorView: View {
    let db: DatabaseClient
    let householdId: String
    let defaultCurrencyCode: String
    let mode: TransactionEditorMode
    let showsDismissButton: Bool
    let prefilledCategoryId: String?
    let onSave: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum FocusField: Hashable {
        case note
    }

    @FocusState private var focusedField: FocusField?

    @State private var categories: [OrdinatioCore.Category] = []
    @State private var model: TransactionEditorModel
    @State private var errorDismissTask: Task<Void, Never>?
    @State private var shouldResetAmountOnNextKeypadInput = false
    @State private var categoryErrorShakeTrigger = 0
    @State private var categoryErrorGlow = false
    @State private var categoryErrorGlowTask: Task<Void, Never>?

    init(
        db: DatabaseClient,
        householdId: String,
        defaultCurrencyCode: String,
        mode: TransactionEditorMode,
        showsDismissButton: Bool = true,
        prefilledCategoryId: String? = nil,
        onSave: (() -> Void)? = nil
    ) {
        self.db = db
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        self.mode = mode
        self.showsDismissButton = showsDismissButton
        self.prefilledCategoryId = prefilledCategoryId
        self.onSave = onSave
        _model = State(
            initialValue: TransactionEditorModel(
                defaultCurrencyCode: defaultCurrencyCode,
                mode: mode,
                prefilledCategoryId: prefilledCategoryId
            )
        )
    }

    private static let amountRequiredErrorMessage = "Amount is required"
    private static let invalidAmountErrorMessage = "Invalid amount"
    private static let amountMustBeGreaterThanZeroErrorMessage = "Amount must be greater than zero"
    private static let categoryRequiredErrorMessage = "Category is required"

    private var selectedCategory: OrdinatioCore.Category? {
        guard let categoryId = model.categoryId else { return nil }
        return categories.first(where: { $0.id == categoryId })
    }

    private var selectedCategoryName: String {
        selectedCategory?.name ?? "Category"
    }

    private var selectedCategoryIconIndex: Int? {
        selectedCategory?.iconIndex
    }

    private func save() {
        focusedField = nil
        model.errorMessage = nil

        let amountTrimmed = model.amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let absMinor = model.parsedAbsMinor else {
            model.errorMessage =
                amountTrimmed.isEmpty ? Self.amountRequiredErrorMessage : Self.invalidAmountErrorMessage
            shouldResetAmountOnNextKeypadInput = true
            playErrorHaptic()
            return
        }

        guard absMinor > 0 else {
            model.errorMessage = Self.amountMustBeGreaterThanZeroErrorMessage
            shouldResetAmountOnNextKeypadInput = true
            playErrorHaptic()
            return
        }

        if case .create = mode, model.categoryId == nil {
            model.errorMessage = Self.categoryRequiredErrorMessage
            triggerCategoryErrorFeedback()
            playErrorHaptic()
            return
        }

        let currency = model.currencyCode.uppercased()
        let signedMinor = model.isExpense ? -absMinor : absMinor
        let localDate = LocalDate.from(date: model.dateTime)
        let now = Date()
        let txnTimestamp = model.dateTime
        let trimmedNote = model.note.trimmingCharacters(in: .whitespacesAndNewlines)

        let txnId: String
        switch mode {
        case .create:
            txnId = UUID().uuidString.lowercased()
        case .edit(let row):
            txnId = row.id
        }

        let txn = Transaction(
            id: txnId,
            householdId: householdId,
            categoryId: model.categoryId,
            amountMinor: signedMinor,
            currencyCode: currency,
            txnDate: localDate.yyyymmdd,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            createdAt: txnTimestamp,
            updatedAt: now
        )

        Task { @MainActor in
            do {
                try await db.upsertTransaction(txn)
                if case .create = mode {
                    playSuccessHaptic()
                    shouldResetAmountOnNextKeypadInput = false
                    model.resetForCreate(
                        defaultCurrencyCode: defaultCurrencyCode,
                        prefilledCategoryId: prefilledCategoryId
                    )
                    onSave?()
                }
                dismiss()
            } catch {
                model.errorMessage = ErrorDisplay.message(error)
            }
        }
    }

    private func deleteTransaction() {
        guard case .edit(let row) = mode else { return }

        let transactionId = row.id
        Task { @MainActor in
            do {
                try await db.deleteTransaction(transactionId: transactionId)
                dismiss()
            } catch {
                model.errorMessage = ErrorDisplay.message(error)
            }
        }
    }

    private func loadCategories() async {
        guard categories.isEmpty else { return }
        do {
            categories = try await db.fetchCategories(householdId: householdId)
        } catch {
            model.errorMessage = ErrorDisplay.message(error)
        }
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ZStack {
                OrdinatioColor.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 18) {
                        amountRow
                        noteField
                    }
                    .padding(.horizontal, OrdinatioMetric.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                    keypadArea
                        .padding(.horizontal, OrdinatioMetric.screenPadding)
                        .padding(.bottom, 22)
                        .keyboardAwareHeight(isEnabled: false, heightScale: 1.05)
                }
            }
            .overlay(alignment: .top) {
                if let errorMessage = model.errorMessage {
                    errorBanner(message: errorMessage)
                        .padding(.horizontal, OrdinatioMetric.screenPadding)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.errorMessage)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadCategories() }
            .sheet(isPresented: $model.showingCategoryPicker) {
                CategoryPickerSheet(
                    db: db,
                    householdId: householdId,
                    categories: $categories,
                    selection: $model.categoryId
                )
            }
            .sheet(isPresented: $model.showingCurrencyPicker) {
                CurrencyPickerSheet(selection: $model.currencyCode)
                    .onDisappear {
                        model.didSelectCurrency()
                    }
            }
            .sheet(isPresented: $model.showingDatePicker) {
                DateAndTimePickerSheet(selection: $model.dateTime)
            }
            .confirmationDialog(
                "Delete this transaction?",
                isPresented: $model.confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteTransaction() }
            }
            .toolbar {
                if showsDismissButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(role: .cancel) {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }

                ToolbarItem(placement: .principal) {
                    Picker("Type", selection: $model.isExpense) {
                        Text("Expense").tag(true)
                        Text("Income").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                    .onChange(of: model.isExpense) {
                        playTypeToggleHaptic()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            model.showingCurrencyPicker = true
                        } label: {
                            Label("Currency", systemImage: "dollarsign.circle")
                        }

                        if case .edit = mode {
                            Button(role: .destructive) {
                                model.confirmDelete = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .accessibilityLabel("More")
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button {
                            focusedField = nil
                        } label: {
                            Label("Close", systemImage: "keyboard.chevron.compact.down")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                                .foregroundStyle(OrdinatioColor.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(OrdinatioColor.surfaceElevated)
                                }
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close keyboard")
                        .accessibilityIdentifier("TransactionNoteCloseKeyboard")
                    }
                }
            }
        }
        .onChange(of: model.errorMessage) { _, newValue in
            errorDismissTask?.cancel()
            guard let newValue else {
                categoryErrorGlowTask?.cancel()
                categoryErrorGlow = false
                return
            }
            errorDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                model.errorMessage = nil
            }

            if newValue != Self.categoryRequiredErrorMessage {
                categoryErrorGlowTask?.cancel()
                categoryErrorGlow = false
            }
        }
        .onDisappear {
            errorDismissTask?.cancel()
            errorDismissTask = nil
            categoryErrorGlowTask?.cancel()
            categoryErrorGlowTask = nil
        }
    }

    private var amountRow: some View {
        @Bindable var model = model

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(model.currencySymbol)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(OrdinatioColor.textSecondary)

            Text(model.formattedAmount)
                .font(.system(size: 54, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(OrdinatioColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
        .accessibilityIdentifier("TransactionAmountField")
    }

    private var noteField: some View {
        @Bindable var model = model

        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OrdinatioColor.textSecondary)

            TextField("Note", text: $model.note)
                .focused($focusedField, equals: .note)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .foregroundStyle(OrdinatioColor.textPrimary)
                .accessibilityIdentifier("TransactionNoteField")

            if !model.note.isEmpty {
                Button {
                    model.note = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear note")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OrdinatioColor.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
        }
    }

    private var chipsRow: some View {
        @Bindable var model = model

        let chipMinHeight = ChipsRowMetrics.minHeight
        let chipSpacing: CGFloat = 10
        let isCategoryError = model.errorMessage == Self.categoryRequiredErrorMessage
        let glowOpacity: CGFloat = isCategoryError && categoryErrorGlow ? 1 : 0
        let glowOpacityDouble = Double(glowOpacity)

        return GeometryReader { proxy in
            let totalWidth = max(proxy.size.width, 0)
            let availableWidth = max(totalWidth - chipSpacing, 0)

            let dateChipWidth = (availableWidth * 0.60).rounded(.down)
            let categoryChipWidth = max(availableWidth - dateChipWidth, 0)

            HStack(spacing: chipSpacing) {
                TransactionChip(
                    label: model.dateTime.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "calendar.badge.clock",
                    tint: .blue,
                    expands: true,
                    minHeight: chipMinHeight
                ) {
                    model.showingDatePicker = true
                }
                .frame(width: dateChipWidth, alignment: .leading)

                Button {
                    model.showingCategoryPicker = true
                } label: {
                    let categoryTint = OrdinatioCategoryVisuals.color(
                        for: selectedCategoryName,
                        iconIndex: selectedCategoryIconIndex
                    )
                    HStack(spacing: 10) {
                        OrdinatioIconTile(
                            symbolName: OrdinatioCategoryVisuals.symbolName(
                                for: selectedCategoryName,
                                iconIndex: selectedCategoryIconIndex
                            ),
                            color: categoryTint,
                            size: ChipsRowMetrics.categoryIconSize
                        )

                        Text(model.categoryId == nil ? "Category" : selectedCategoryName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OrdinatioColor.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: chipMinHeight, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill((isCategoryError ? OrdinatioColor.expense : categoryTint).opacity(0.14))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                (isCategoryError ? OrdinatioColor.expense : categoryTint).opacity(0.40),
                                lineWidth: 1.3
                            )
                    }
                    .overlay {
                        if isCategoryError {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(OrdinatioColor.expense.opacity(0.9 * glowOpacityDouble), lineWidth: 2)
                                .shadow(
                                    color: OrdinatioColor.expense.opacity(0.55 * glowOpacityDouble),
                                    radius: 10 * glowOpacity
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Category")
                .frame(width: categoryChipWidth, alignment: .leading)
                .modifier(
                    ShakeEffect(
                        travelDistance: 4,
                        shakesPerUnit: 2,
                        animatableData: CGFloat(categoryErrorShakeTrigger)
                    )
                )
            }
        }
        .frame(height: chipMinHeight)
        .padding(.vertical, ChipsRowMetrics.verticalPadding)
    }

    private var keypadArea: some View {
        @Bindable var model = model

        let hasInput = !model.amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return GeometryReader { proxy in
            let rowSpacing: CGFloat = 12
            let chipHeight = ChipsRowMetrics.height
            let buttonRows: CGFloat = 5
            let totalRowSpacing = rowSpacing * 5
            let availableForButtons = proxy.size.height - chipHeight - totalRowSpacing
            let buttonHeight = max(availableForButtons / buttonRows, 44)
            let submitButtonHeight = buttonHeight
            let cornerRadius = min(18, buttonHeight / 3)
            let submitCornerRadius = min(18, submitButtonHeight / 3)

            VStack(spacing: rowSpacing) {
                keypadNumberRow([1, 2, 3], height: buttonHeight, cornerRadius: cornerRadius)
                keypadNumberRow([4, 5, 6], height: buttonHeight, cornerRadius: cornerRadius)
                keypadNumberRow([7, 8, 9], height: buttonHeight, cornerRadius: cornerRadius)

                HStack(spacing: 12) {
                    keypadButton(title: ".", role: .secondary, height: buttonHeight, cornerRadius: cornerRadius) {
                        prepareForAmountKeypadInput()
                        model.appendDecimalSeparator()
                    }
                    .accessibilityIdentifier("TransactionKeypadDecimal")
                    .disabled(model.fractionDigits == 0)

                    keypadButton(title: "0", role: .secondary, height: buttonHeight, cornerRadius: cornerRadius) {
                        prepareForAmountKeypadInput()
                        model.appendDigit(0)
                    }
                    .accessibilityIdentifier("TransactionKeypadDigit0")

                    keypadButton(
                        systemImage: "delete.left",
                        role: .secondary,
                        height: buttonHeight,
                        cornerRadius: cornerRadius
                    ) {
                        shouldResetAmountOnNextKeypadInput = false
                        if isAmountValidationError(model.errorMessage) {
                            model.errorMessage = nil
                        }
                        model.deleteLastInput()
                    }
                    .accessibilityLabel("Backspace")
                    .accessibilityIdentifier("TransactionKeypadBackspace")
                    .disabled(!hasInput)
                }

                chipsRow

                keypadButton(
                    title: submitButtonTitle,
                    role: .primary,
                    height: submitButtonHeight,
                    cornerRadius: submitCornerRadius
                ) {
                    save()
                }
                .accessibilityIdentifier("TransactionSubmitButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keypad")
        .accessibilityIdentifier("TransactionKeypad")
    }

    private enum ChipsRowMetrics {
        static let chipVerticalPadding: CGFloat = 10
        static let categoryIconSize: CGFloat = 26
        static let verticalPadding: CGFloat = 2
        static let minHeight: CGFloat = categoryIconSize + (chipVerticalPadding * 2)
        static let height: CGFloat = minHeight + (verticalPadding * 2)
    }

    private var submitButtonTitle: String {
        switch mode {
        case .create:
            return "Add"
        case .edit:
            return "Save"
        }
    }

    private func keypadNumberRow(_ digits: [Int], height: CGFloat, cornerRadius: CGFloat) -> some View {
        @Bindable var model = model

        return HStack(spacing: 12) {
            ForEach(digits, id: \.self) { digit in
                keypadButton(title: "\(digit)", role: .secondary, height: height, cornerRadius: cornerRadius) {
                    prepareForAmountKeypadInput()
                    model.appendDigit(digit)
                }
                .accessibilityIdentifier("TransactionKeypadDigit\(digit)")
            }
        }
    }

    private enum KeypadRole {
        case primary
        case secondary
    }

    private func keypadButton(
        title: String,
        role: KeypadRole,
        height: CGFloat,
        cornerRadius: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            playKeypadHaptic(intensity: 0.5)
            action()
        } label: {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(role == .primary ? OrdinatioColor.background : OrdinatioColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: height)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(role == .primary ? OrdinatioColor.textPrimary : OrdinatioColor.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: role == .primary ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func keypadButton(
        systemImage: String,
        role: KeypadRole,
        height: CGFloat,
        cornerRadius: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            playKeypadHaptic(intensity: 0.5)
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(role == .primary ? OrdinatioColor.background : OrdinatioColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: height)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(role == .primary ? OrdinatioColor.textPrimary : OrdinatioColor.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: role == .primary ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        if dynamicTypeSize > .xLarge {
            errorBannerContent(message: message)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            errorBannerContent(message: message)
                .frame(width: 250)
        }
    }

    private func errorBannerContent(message: String) -> some View {
        HStack(spacing: 6.5) {
            Image(systemName: errorSymbolName(for: message))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(OrdinatioColor.expense)

            Text(message)
                .font(.system(.callout, design: .rounded).weight(.semibold))
                .foregroundStyle(OrdinatioColor.expense)
                .multilineTextAlignment(.leading)
        }
        .padding(8)
        .background(
            OrdinatioColor.expense.opacity(0.23),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .accessibilityIdentifier("TransactionErrorBanner")
    }

    private func errorSymbolName(for message: String) -> String {
        switch message {
        case Self.amountRequiredErrorMessage, Self.amountMustBeGreaterThanZeroErrorMessage:
            return "centsign.circle"
        case Self.invalidAmountErrorMessage:
            return "questionmark.app"
        case Self.categoryRequiredErrorMessage:
            return "tag.fill"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

    private func playErrorHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    private func playTypeToggleHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }

    private func playKeypadHaptic(intensity: CGFloat) {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: min(intensity, 1.0))
    }

    private func playSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    private func triggerCategoryErrorFeedback() {
        categoryErrorGlowTask?.cancel()
        categoryErrorGlow = false
        withAnimation(.easeInOut(duration: 0.55)) {
            categoryErrorShakeTrigger += 1
        }
        withAnimation(.easeOut(duration: 0.15)) {
            categoryErrorGlow = true
        }
        categoryErrorGlowTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.6)) {
                categoryErrorGlow = false
            }
        }
    }

    private func prepareForAmountKeypadInput() {
        if shouldResetAmountOnNextKeypadInput {
            model.amountText = ""
            shouldResetAmountOnNextKeypadInput = false
        }

        if isAmountValidationError(model.errorMessage) {
            model.errorMessage = nil
        }
    }

    private func isAmountValidationError(_ message: String?) -> Bool {
        switch message {
        case Self.amountRequiredErrorMessage,
             Self.invalidAmountErrorMessage,
             Self.amountMustBeGreaterThanZeroErrorMessage:
            return true
        default:
            return false
        }
    }
}

private struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 4
    var shakesPerUnit: CGFloat = 2
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = travelDistance * sin(animatableData * .pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

private struct KeyboardAwareHeightModifier: ViewModifier {
    @AppStorage(PreferencesKeys.transactionEditorKeyboardHeight)
    private var savedKeyboardHeight: Double = Double(UIScreen.main.bounds.height / 2.5)

    let isEnabled: Bool
    let minimumUpdateHeight: CGFloat
    let heightAdjustment: CGFloat
    let heightScale: CGFloat

    init(isEnabled: Bool, minimumUpdateHeight: CGFloat, heightAdjustment: CGFloat, heightScale: CGFloat) {
        self.isEnabled = isEnabled
        self.minimumUpdateHeight = minimumUpdateHeight
        self.heightAdjustment = heightAdjustment
        self.heightScale = heightScale
    }

    func body(content: Content) -> some View {
        content
            .frame(height: savedKeyboardHeight * Double(heightScale))
            .task(id: isEnabled) {
                guard isEnabled else { return }
                for await notification in NotificationCenter.default.notifications(
                    named: UIResponder.keyboardWillChangeFrameNotification
                ) {
                    guard let value = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
                        continue
                    }

                    let endFrame = value.cgRectValue
                    let screenHeight = UIScreen.main.bounds.height
                    let overlap = max(0, screenHeight - endFrame.minY)
                    let adjusted = max(0, overlap - heightAdjustment)

                    // Ignore non-keyboard changes (e.g. undocked/floating) and keep the last known good height.
                    guard adjusted >= minimumUpdateHeight else { continue }

                    await MainActor.run {
                        savedKeyboardHeight = Double(adjusted)
                    }
                }
            }
    }
}

private extension View {
    func keyboardAwareHeight(
        isEnabled: Bool = true,
        minimumUpdateHeight: CGFloat = 200,
        heightAdjustment: CGFloat = 0,
        heightScale: CGFloat = 1
    ) -> some View {
        modifier(
            KeyboardAwareHeightModifier(
                isEnabled: isEnabled,
                minimumUpdateHeight: minimumUpdateHeight,
                heightAdjustment: heightAdjustment,
                heightScale: heightScale
            )
        )
    }
}
