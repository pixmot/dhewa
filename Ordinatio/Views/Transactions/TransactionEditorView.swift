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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum FocusField: Hashable {
        case note
    }

    @FocusState private var focusedField: FocusField?

    @State private var categories: [OrdinatioCore.Category] = []
    @State private var model: TransactionEditorModel
    @State private var errorDismissTask: Task<Void, Never>?

    init(
        db: DatabaseClient,
        householdId: String,
        defaultCurrencyCode: String,
        mode: TransactionEditorMode,
        showsDismissButton: Bool = true,
        prefilledCategoryId: String? = nil
    ) {
        self.db = db
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        self.mode = mode
        self.showsDismissButton = showsDismissButton
        self.prefilledCategoryId = prefilledCategoryId
        _model = State(
            initialValue: TransactionEditorModel(
                defaultCurrencyCode: defaultCurrencyCode,
                mode: mode,
                prefilledCategoryId: prefilledCategoryId
            )
        )
    }

    private var selectedCategoryName: String {
        guard let categoryId = model.categoryId else { return "Category" }
        return categories.first(where: { $0.id == categoryId })?.name ?? "Category"
    }

    private func save() {
        focusedField = nil
        model.errorMessage = nil

        let amountTrimmed = model.amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let absMinor = model.parsedAbsMinor else {
            model.errorMessage = amountTrimmed.isEmpty ? "Amount is required" : "Invalid amount"
            playErrorHaptic()
            return
        }

        guard absMinor > 0 else {
            model.errorMessage = "Amount must be greater than zero"
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
                        .keyboardAwareHeight(isEnabled: false, heightScale: 1.5)
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
                CategoryPickerSheet(categories: categories, selection: $model.categoryId)
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

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
        .onChange(of: model.errorMessage) { _, newValue in
            errorDismissTask?.cancel()
            guard newValue != nil else { return }
            errorDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                model.errorMessage = nil
            }
        }
        .onDisappear {
            errorDismissTask?.cancel()
            errorDismissTask = nil
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
                    HStack(spacing: 10) {
                        OrdinatioIconTile(
                            symbolName: OrdinatioCategoryVisuals.symbolName(for: selectedCategoryName),
                            color: OrdinatioCategoryVisuals.color(for: selectedCategoryName),
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
                            .fill(OrdinatioCategoryVisuals.color(for: selectedCategoryName).opacity(0.14))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                OrdinatioCategoryVisuals.color(for: selectedCategoryName).opacity(0.30), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Category")
                .frame(width: categoryChipWidth, alignment: .leading)
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
            let cornerRadius = min(18, buttonHeight / 3)

            VStack(spacing: rowSpacing) {
                keypadNumberRow([1, 2, 3], height: buttonHeight, cornerRadius: cornerRadius)
                keypadNumberRow([4, 5, 6], height: buttonHeight, cornerRadius: cornerRadius)
                keypadNumberRow([7, 8, 9], height: buttonHeight, cornerRadius: cornerRadius)

                HStack(spacing: 12) {
                    keypadButton(title: ".", role: .secondary, height: buttonHeight, cornerRadius: cornerRadius) {
                        model.appendDecimalSeparator()
                    }
                    .accessibilityIdentifier("TransactionKeypadDecimal")
                    .disabled(model.fractionDigits == 0)

                    keypadButton(title: "0", role: .secondary, height: buttonHeight, cornerRadius: cornerRadius) {
                        model.appendDigit(0)
                    }
                    .accessibilityIdentifier("TransactionKeypadDigit0")

                    keypadButton(
                        systemImage: "delete.left",
                        role: .secondary,
                        height: buttonHeight,
                        cornerRadius: cornerRadius
                    ) {
                        model.deleteLastInput()
                    }
                    .accessibilityLabel("Backspace")
                    .accessibilityIdentifier("TransactionKeypadBackspace")
                    .disabled(!hasInput)
                }

                chipsRow

                keypadButton(title: submitButtonTitle, role: .primary, height: buttonHeight, cornerRadius: cornerRadius) {
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
        Button(action: action) {
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
        Button(action: action) {
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
        case "Amount is required", "Amount must be greater than zero":
            return "centsign.circle"
        case "Invalid amount":
            return "questionmark.app"
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
