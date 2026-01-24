import OrdinatioCore
import SwiftUI

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
    @State private var isExpense: Bool
    @State private var amountText: String
    @State private var currencyCode: String
    @State private var fractionDigits: Int
    @State private var dateTime: Date
    @State private var categoryId: String?
    @State private var note: String
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @State private var showingCategoryPicker = false
    @State private var showingCurrencyPicker = false
    @State private var showingDatePicker = false
    @State private var showingTimePicker = false

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

        switch mode {
        case .create:
            _isExpense = State(initialValue: true)
            _amountText = State(initialValue: "")
            _currencyCode = State(initialValue: defaultCurrencyCode.uppercased())
            _fractionDigits = State(initialValue: MoneyFormat.fractionDigits(for: defaultCurrencyCode))
            _dateTime = State(initialValue: Date())
            _categoryId = State(initialValue: prefilledCategoryId)
            _note = State(initialValue: "")
        case .edit(let row):
            _isExpense = State(initialValue: row.amountMinor < 0)
            _amountText = State(
                initialValue: Self.entryAmountText(absMinor: abs(row.amountMinor), currencyCode: row.currencyCode))
            _currencyCode = State(initialValue: row.currencyCode.uppercased())
            _fractionDigits = State(initialValue: MoneyFormat.fractionDigits(for: row.currencyCode))
            _dateTime = State(initialValue: Self.initialDateTime(txnDate: row.txnDate, createdAt: row.createdAt))
            _categoryId = State(initialValue: row.categoryId)
            _note = State(initialValue: row.note ?? "")
        }
    }

    static func entryAmountText(absMinor: Int64, currencyCode: String) -> String {
        let digits = MoneyFormat.fractionDigits(for: currencyCode)
        return format(absMinor: absMinor, fractionDigits: digits)
    }

    static func initialDateTime(txnDate: Int32, createdAt: Date) -> Date {
        let calendar = Calendar.current
        let day = LocalDate(yyyymmdd: txnDate).date(calendar: calendar)
        let time = calendar.dateComponents([.hour, .minute, .second], from: createdAt)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: day
        ) ?? createdAt
    }

    private var selectedCategoryName: String {
        guard let categoryId else { return "Category" }
        return categories.first(where: { $0.id == categoryId })?.name ?? "Category"
    }

    private static let currencySymbolFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter
    }()

    private static func pow10Int64(_ digits: Int) -> Int64? {
        guard digits >= 0 else { return nil }
        var value: Int64 = 1
        for _ in 0..<digits {
            let (next, overflow) = value.multipliedReportingOverflow(by: 10)
            if overflow { return nil }
            value = next
        }
        return value
    }

    private static func format(absMinor: Int64, fractionDigits: Int) -> String {
        guard let multiplier = pow10Int64(fractionDigits), multiplier > 0 else { return "" }

        if fractionDigits == 0 {
            return String(absMinor)
        }

        let whole = absMinor / multiplier
        let fraction = absMinor % multiplier
        let fractionText = String(fraction)
        let zeros = String(repeating: "0", count: max(0, fractionDigits - fractionText.count))
        return "\(whole).\(zeros)\(fractionText)"
    }

    private static func parseAbsMinor(from input: String, fractionDigits: Int) -> Int64? {
        let trimmed =
            input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        guard !trimmed.isEmpty else { return nil }
        guard let multiplier = pow10Int64(fractionDigits), multiplier > 0 else { return nil }

        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2 else { return nil }

        let wholePart = parts.first ?? ""
        let fractionPart = parts.count == 2 ? parts[1] : ""

        guard wholePart.allSatisfy({ $0.isNumber }) else { return nil }
        guard fractionPart.allSatisfy({ $0.isNumber }) else { return nil }

        let whole: Int64
        if wholePart.isEmpty {
            whole = 0
        } else {
            guard let parsedWhole = Int64(wholePart) else { return nil }
            whole = parsedWhole
        }
        if fractionDigits == 0 {
            return whole
        }

        let fractionPrefix = fractionPart.prefix(fractionDigits)
        let fractionPadded = String(fractionPrefix).padding(toLength: fractionDigits, withPad: "0", startingAt: 0)
        guard let fraction = Int64(fractionPadded) else { return nil }

        let (scaledWhole, overflow1) = whole.multipliedReportingOverflow(by: multiplier)
        if overflow1 { return nil }
        let (total, overflow2) = scaledWhole.addingReportingOverflow(fraction)
        if overflow2 { return nil }
        return total
    }

    private var parsedAbsMinor: Int64? {
        Self.parseAbsMinor(from: amountText, fractionDigits: fractionDigits)
    }

    private var formattedAmount: String {
        guard let parsedAbsMinor else {
            return fractionDigits == 0 ? "0" : "0." + String(repeating: "0", count: fractionDigits)
        }
        return Self.format(absMinor: parsedAbsMinor, fractionDigits: fractionDigits)
    }

    private var currencySymbol: String {
        Self.currencySymbolFormatter.currencyCode = currencyCode.uppercased()
        return Self.currencySymbolFormatter.currencySymbol ?? currencyCode.uppercased()
    }

    private var canSave: Bool {
        (parsedAbsMinor ?? 0) > 0
    }

    private func appendDigit(_ digit: Int) {
        guard (0...9).contains(digit) else { return }
        let separator = "."

        var next =
            amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        if next == "0" && !next.contains(separator) {
            next = "\(digit)"
            amountText = next
            return
        }

        if let separatorIndex = next.firstIndex(of: Character(separator)) {
            let fractionCount = next.distance(from: next.index(after: separatorIndex), to: next.endIndex)
            guard fractionCount < fractionDigits else { return }
        }

        if next.isEmpty {
            amountText = "\(digit)"
            return
        }

        amountText = next + "\(digit)"
    }

    private func appendDecimalSeparator() {
        guard fractionDigits > 0 else { return }
        let separator = "."

        var next =
            amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        guard !next.contains(separator) else { return }
        if next.isEmpty { next = "0" }
        amountText = next + separator
    }

    private func deleteLastInput() {
        var next =
            amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        guard !next.isEmpty else { return }

        next.removeLast()
        amountText = next
    }

    private func normalizeAmountTextForCurrency() {
        let separator = "."
        var next =
            amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        if fractionDigits == 0 {
            if let idx = next.firstIndex(of: Character(separator)) {
                next = String(next[..<idx])
            }
            amountText = next
            return
        }

        if let idx = next.firstIndex(of: Character(separator)) {
            let fraction = next[next.index(after: idx)...]
            if fraction.count > fractionDigits {
                let end = fraction.index(fraction.startIndex, offsetBy: fractionDigits)
                amountText = String(next[..<next.index(after: idx)]) + fraction[..<end]
            } else {
                amountText = next
            }
            return
        }

        amountText = next
    }

    private func save() {
        focusedField = nil
        errorMessage = nil

        let amountTrimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let absMinor = parsedAbsMinor else {
            errorMessage = amountTrimmed.isEmpty ? "Amount is required" : "Invalid amount"
            return
        }

        guard absMinor > 0 else {
            errorMessage = "Amount must be greater than zero"
            return
        }

        let currency = currencyCode.uppercased()
        let signedMinor = isExpense ? -absMinor : absMinor
        let localDate = LocalDate.from(date: dateTime)
        let now = Date()
        let txnTimestamp = dateTime
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

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
            categoryId: categoryId,
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
                errorMessage = ErrorDisplay.message(error)
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
                errorMessage = ErrorDisplay.message(error)
            }
        }
    }

    private func loadCategories() async {
        guard categories.isEmpty else { return }
        do {
            categories = try await db.fetchCategories(householdId: householdId)
        } catch {
            errorMessage = ErrorDisplay.message(error)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OrdinatioColor.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
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
                        keypad
                            .padding(.horizontal, OrdinatioMetric.screenPadding)
                            .padding(.bottom, 22)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Spacer(minLength: 0)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.20), value: focusedField)
            .task { await loadCategories() }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerSheet(categories: categories, selection: $categoryId)
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerSheet(selection: $currencyCode)
                    .onDisappear {
                        fractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
                        normalizeAmountTextForCurrency()
                    }
            }
            .sheet(isPresented: $showingDatePicker) {
                DateTimePickerSheet(
                    title: "Date",
                    selection: $dateTime,
                    displayedComponents: .date,
                    style: .graphical
                )
            }
            .sheet(isPresented: $showingTimePicker) {
                DateTimePickerSheet(
                    title: "Time",
                    selection: $dateTime,
                    displayedComponents: .hourAndMinute,
                    style: .wheel
                )
            }
            .confirmationDialog(
                "Delete this transaction?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteTransaction() }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: {
                        errorMessage != nil
                    },
                    set: { newValue in
                        if !newValue { errorMessage = nil }
                    })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
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
                    Picker("Type", selection: $isExpense) {
                        Text("Expense").tag(true)
                        Text("Income").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingCurrencyPicker = true
                        } label: {
                            Label("Currency", systemImage: "dollarsign.circle")
                        }

                        if case .edit = mode {
                            Button(role: .destructive) {
                                confirmDelete = true
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
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(currencySymbol)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(OrdinatioColor.textSecondary)

            Text(formattedAmount)
                .font(.system(size: 54, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(OrdinatioColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            Button {
                deleteLastInput()
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
            .disabled(amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Backspace")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
        .accessibilityIdentifier("TransactionAmountField")
    }

    private var noteField: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OrdinatioColor.textSecondary)

            TextField("Note", text: $note)
                .focused($focusedField, equals: .note)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .foregroundStyle(OrdinatioColor.textPrimary)
                .accessibilityIdentifier("TransactionNoteField")

            if !note.isEmpty {
                Button {
                    note = ""
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                TransactionChip(
                    label: dateTime.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar",
                    tint: .blue
                ) {
                    showingDatePicker = true
                }

                TransactionChip(
                    label: dateTime.formatted(date: .omitted, time: .shortened),
                    systemImage: "clock",
                    tint: .orange
                ) {
                    showingTimePicker = true
                }

                Button {
                    showingCategoryPicker = true
                } label: {
                    HStack(spacing: 10) {
                        OrdinatioIconTile(
                            symbolName: OrdinatioCategoryVisuals.symbolName(for: selectedCategoryName),
                            color: OrdinatioCategoryVisuals.color(for: selectedCategoryName),
                            size: 26
                        )

                        Text(categoryId == nil ? "Category" : selectedCategoryName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OrdinatioColor.textPrimary)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
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
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var keypad: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
            spacing: 12
        ) {
            keypadNumberRow([1, 2, 3])
            keypadNumberRow([4, 5, 6])
            keypadNumberRow([7, 8, 9])

            keypadButton(title: ".", role: .secondary) { appendDecimalSeparator() }
                .accessibilityIdentifier("TransactionKeypadDecimal")
                .disabled(fractionDigits == 0)

            keypadButton(title: "0", role: .secondary) { appendDigit(0) }
                .accessibilityIdentifier("TransactionKeypadDigit0")

            keypadButton(systemImage: "checkmark", role: .primary) { save() }
                .accessibilityIdentifier("TransactionKeypadSave")
                .disabled(!canSave)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keypad")
        .accessibilityIdentifier("TransactionKeypad")
    }

    private func keypadNumberRow(_ digits: [Int]) -> some View {
        ForEach(digits, id: \.self) { digit in
            keypadButton(title: "\(digit)", role: .secondary) { appendDigit(digit) }
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
        .accessibilityLabel("Save")
    }
}

private struct TransactionChip: View {
    let label: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)

                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textPrimary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OrdinatioColor.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(OrdinatioColor.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryPickerSheet: View {
    let categories: [OrdinatioCore.Category]
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [OrdinatioCore.Category] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return categories }
        return categories.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selection = nil
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        OrdinatioIconTile(
                            symbolName: OrdinatioCategoryVisuals.symbolName(for: "Uncategorized"),
                            color: OrdinatioCategoryVisuals.color(for: "Uncategorized"),
                            size: 30
                        )

                        Text("Uncategorized")
                            .foregroundStyle(OrdinatioColor.textPrimary)

                        Spacer(minLength: 0)

                        if selection == nil {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(OrdinatioColor.background)

                ForEach(filtered) { category in
                    Button {
                        selection = category.id
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            OrdinatioIconTile(
                                symbolName: OrdinatioCategoryVisuals.symbolName(for: category.name),
                                color: OrdinatioCategoryVisuals.color(for: category.name),
                                size: 30
                            )

                            Text(category.name)
                                .foregroundStyle(OrdinatioColor.textPrimary)

                            Spacer(minLength: 0)

                            if selection == category.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(OrdinatioColor.background)
                }
            }
            .scrollContentBackground(.hidden)
            .background(OrdinatioColor.background)
            .navigationTitle("Category")
            .searchable(text: $searchText, prompt: "Search categories")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct CurrencyPickerSheet: View {
    @Binding var selection: String

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private static let currencySymbolCache: [String: String] = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current

        var cache: [String: String] = [:]
        for code in Locale.commonISOCurrencyCodes {
            let upper = code.uppercased()
            formatter.currencyCode = upper
            cache[upper] = formatter.currencySymbol ?? upper
        }
        return cache
    }()

    private var currencyCodes: [String] {
        let all = Locale.commonISOCurrencyCodes
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return all }
        return all.filter { code in
            let name = Locale.current.localizedString(forCurrencyCode: code) ?? ""
            return code.lowercased().contains(query) || name.lowercased().contains(query)
        }
    }

    private func currencyTitle(_ code: String) -> String {
        let upper = code.uppercased()
        let name = Locale.current.localizedString(forCurrencyCode: upper) ?? upper
        let symbol = Self.currencySymbolCache[upper] ?? upper
        return "\(upper) — \(name) (\(symbol))"
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(currencyCodes, id: \.self) { code in
                    Button {
                        selection = code.uppercased()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            OrdinatioIconTile(
                                symbolName: "banknote.fill",
                                color: OrdinatioCategoryVisuals.color(for: code),
                                size: 30
                            )

                            Text(currencyTitle(code))
                                .foregroundStyle(OrdinatioColor.textPrimary)

                            Spacer(minLength: 0)

                            if selection.uppercased() == code.uppercased() {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(OrdinatioColor.background)
                }
            }
            .scrollContentBackground(.hidden)
            .background(OrdinatioColor.background)
            .navigationTitle("Currency")
            .searchable(text: $searchText, prompt: "Search currencies")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct DateTimePickerSheet: View {
    enum PickerStyle {
        case graphical
        case wheel
    }

    let title: String
    @Binding var selection: Date
    let displayedComponents: DatePickerComponents
    let style: PickerStyle

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    switch style {
                    case .graphical:
                        DatePicker(title, selection: $selection, displayedComponents: displayedComponents)
                            .datePickerStyle(.graphical)
                    case .wheel:
                        DatePicker(title, selection: $selection, displayedComponents: displayedComponents)
                            .datePickerStyle(.wheel)
                    }
                }
                .labelsHidden()
                .padding(.horizontal, OrdinatioMetric.screenPadding)
                .padding(.top, 10)

                Spacer(minLength: 0)
            }
            .background(OrdinatioColor.background)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
