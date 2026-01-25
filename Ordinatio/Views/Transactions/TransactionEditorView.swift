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

    enum FocusField: Hashable {
        case note
    }

    @FocusState private var focusedField: FocusField?

    @State private var categories: [OrdinatioCore.Category] = []
    @State private var model: TransactionEditorModel

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
                    if let errorMessage = model.errorMessage {
                        errorBanner(message: errorMessage)
                            .padding(.horizontal, OrdinatioMetric.screenPadding)
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ScrollView {
                        VStack(spacing: 18) {
                            amountRow
                            noteField
                            chipsRow
                        }
                        .padding(.horizontal, OrdinatioMetric.screenPadding)
                        .padding(.top, 8)
                        .padding(.bottom, 18)
                    }

                    if focusedField == nil {
                        VStack(spacing: 12) {
                            keypad
                            submitButton
                        }
                        .padding(.horizontal, OrdinatioMetric.screenPadding)
                        .padding(.bottom, 22)
                    } else {
                        Spacer(minLength: 0)
                    }
                }
            }
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
                    .onChange(of: model.isExpense) { _ in
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
                        Image(systemName: "arrow.2.circlepath")
                    }
                    .accessibilityLabel("More")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
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

            Button {
                model.deleteLastInput()
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .frame(width: 32, height: 32)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(OrdinatioColor.surface)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(OrdinatioColor.separator.opacity(0.8), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .disabled(model.amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Backspace")
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

        let chipVerticalPadding: CGFloat = 10
        let categoryIconSize: CGFloat = 26
        let chipMinHeight = categoryIconSize + (chipVerticalPadding * 2)
        let chipSpacing: CGFloat = 10

        return HStack(spacing: chipSpacing) {
            TransactionChip(
                label: model.dateTime.formatted(date: .abbreviated, time: .shortened),
                systemImage: "calendar.badge.clock",
                tint: .blue,
                expands: true,
                minHeight: chipMinHeight
            ) {
                model.showingDatePicker = true
            }
            .containerRelativeFrame(.horizontal, count: 100, span: 65, spacing: chipSpacing)

            Button {
                model.showingCategoryPicker = true
            } label: {
                HStack(spacing: 10) {
                    OrdinatioIconTile(
                        symbolName: OrdinatioCategoryVisuals.symbolName(for: selectedCategoryName),
                        color: OrdinatioCategoryVisuals.color(for: selectedCategoryName),
                        size: categoryIconSize
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
            .containerRelativeFrame(.horizontal, count: 100, span: 35, spacing: chipSpacing)
        }
        .padding(.vertical, 2)
    }

    private var keypad: some View {
        @Bindable var model = model

        let hasInput = !model.amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
            spacing: 12
        ) {
            keypadNumberRow([1, 2, 3])
            keypadNumberRow([4, 5, 6])
            keypadNumberRow([7, 8, 9])

            keypadButton(title: ".", role: .secondary) { model.appendDecimalSeparator() }
                .accessibilityIdentifier("TransactionKeypadDecimal")
                .disabled(model.fractionDigits == 0)

            keypadButton(title: "0", role: .secondary) { model.appendDigit(0) }
                .accessibilityIdentifier("TransactionKeypadDigit0")

            keypadButton(systemImage: "delete.left", role: .secondary) { model.deleteLastInput() }
                .accessibilityLabel("Backspace")
                .accessibilityIdentifier("TransactionKeypadBackspace")
                .disabled(!hasInput)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keypad")
        .accessibilityIdentifier("TransactionKeypad")
    }

    private var submitButton: some View {
        @Bindable var model = model

        return keypadButton(title: submitButtonTitle, role: .primary) { save() }
            .accessibilityIdentifier("TransactionSubmitButton")
    }

    private var submitButtonTitle: String {
        switch mode {
        case .create:
            return "Add"
        case .edit:
            return "Save"
        }
    }

    private func keypadNumberRow(_ digits: [Int]) -> some View {
        @Bindable var model = model

        return ForEach(digits, id: \.self) { digit in
            keypadButton(title: "\(digit)", role: .secondary) { model.appendDigit(digit) }
                .accessibilityIdentifier("TransactionKeypadDigit\(digit)")
        }
    }

    private enum KeypadRole {
        case primary
        case secondary
    }

    private func keypadButton(
        title: String,
        role: KeypadRole,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(role == .primary ? OrdinatioColor.background : OrdinatioColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(role == .primary ? OrdinatioColor.textPrimary : OrdinatioColor.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: role == .primary ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func keypadButton(
        systemImage: String,
        role: KeypadRole,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(role == .primary ? OrdinatioColor.background : OrdinatioColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(role == .primary ? OrdinatioColor.textPrimary : OrdinatioColor.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: role == .primary ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OrdinatioColor.expense)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OrdinatioColor.expense)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(OrdinatioColor.expense.opacity(0.12))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(OrdinatioColor.expense.opacity(0.4), lineWidth: 1)
        }
        .accessibilityIdentifier("TransactionErrorBanner")
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
