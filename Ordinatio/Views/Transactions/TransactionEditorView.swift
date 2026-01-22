import GRDB
import SwiftUI
import OrdinatioCore

enum TransactionEditorMode: Hashable {
    case create
    case edit(TransactionListRow)
}

struct TransactionEditorView: View {
    let database: AppDatabase
    let householdId: String
    let defaultCurrencyCode: String
    let mode: TransactionEditorMode

    @Environment(\.dismiss) private var dismiss

    enum FocusField: Hashable {
        case note
    }

    @FocusState private var focusedField: FocusField?

    @State private var categories: [OrdinatioCore.Category] = []
    @State private var isExpense: Bool
    @State private var amountText: String
    @State private var currencyCode: String
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
        database: AppDatabase,
        householdId: String,
        defaultCurrencyCode: String,
        mode: TransactionEditorMode
    ) {
        self.database = database
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        self.mode = mode

        switch mode {
        case .create:
            _isExpense = State(initialValue: true)
            _amountText = State(initialValue: "")
            _currencyCode = State(initialValue: defaultCurrencyCode.uppercased())
            _dateTime = State(initialValue: Date())
            _categoryId = State(initialValue: nil)
            _note = State(initialValue: "")
        case let .edit(row):
            _isExpense = State(initialValue: row.amountMinor < 0)
            _amountText = State(initialValue: Self.entryAmountText(absMinor: abs(row.amountMinor), currencyCode: row.currencyCode))
            _currencyCode = State(initialValue: row.currencyCode.uppercased())
            _dateTime = State(initialValue: Self.initialDateTime(txnDate: row.txnDate, createdAt: row.createdAt))
            _categoryId = State(initialValue: row.categoryId)
            _note = State(initialValue: row.note ?? "")
        }
    }

    static func entryAmountText(absMinor: Int64, currencyCode: String) -> String {
        let decimal = MoneyFormat.decimal(fromMinorUnits: absMinor, currencyCode: currencyCode)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
        formatter.maximumFractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? ""
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

    private var formattedAmount: String {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let digits = MoneyFormat.fractionDigits(for: currencyCode)
            return digits == 0 ? "0" : "0." + String(repeating: "0", count: digits)
        }

        switch MoneyFormat.parseMinorUnits(trimmed, currencyCode: currencyCode.uppercased()) {
        case let .success(minor):
            let decimal = MoneyFormat.decimal(fromMinorUnits: abs(minor), currencyCode: currencyCode)
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = .current
            formatter.minimumFractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
            formatter.maximumFractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
            return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? trimmed
        case .failure:
            return trimmed
        }
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode.uppercased()
        return formatter.currencySymbol ?? currencyCode.uppercased()
    }

    private var canSave: Bool {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        switch MoneyFormat.parseMinorUnits(trimmed, currencyCode: currencyCode.uppercased()) {
        case let .success(minor):
            return abs(minor) > 0
        case .failure:
            return false
        }
    }

    private func appendDigit(_ digit: Int) {
        guard (0...9).contains(digit) else { return }
        let fractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
        let separator = "."

        var next = amountText
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
        let fractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
        guard fractionDigits > 0 else { return }
        let separator = "."

        var next = amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        guard !next.contains(separator) else { return }
        if next.isEmpty { next = "0" }
        amountText = next + separator
    }

    private func deleteLastInput() {
        var next = amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        guard !next.isEmpty else { return }

        next.removeLast()
        amountText = next
    }

    private func normalizeAmountTextForCurrency() {
        let separator = "."
        var next = amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")

        let fractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
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
        guard !amountTrimmed.isEmpty else {
            errorMessage = "Amount is required"
            return
        }

        let currency = currencyCode.uppercased()
        let absMinor: Int64
        switch MoneyFormat.parseMinorUnits(amountTrimmed, currencyCode: currency) {
        case let .success(minor):
            absMinor = minor
        case .failure:
            errorMessage = "Invalid amount"
            return
        }

        let normalizedAbsMinor = abs(absMinor)
        guard normalizedAbsMinor > 0 else {
            errorMessage = "Amount must be greater than zero"
            return
        }

        let signedMinor = isExpense ? -normalizedAbsMinor : normalizedAbsMinor
        let localDate = LocalDate.from(date: dateTime)
        let now = Date()
        let txnTimestamp = dateTime
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try database.write { db in
                switch mode {
                case .create:
                    let txn = Transaction(
                        id: UUID().uuidString.lowercased(),
                        householdId: householdId,
                        categoryId: categoryId,
                        amountMinor: signedMinor,
                        currencyCode: currency,
                        txnDate: localDate.yyyymmdd,
                        note: trimmedNote.isEmpty ? nil : trimmedNote,
                        createdAt: txnTimestamp,
                        updatedAt: now
                    )
                    try TransactionRepository.upsertTransaction(in: db, transaction: txn)
                case let .edit(row):
                    let txn = Transaction(
                        id: row.id,
                        householdId: householdId,
                        categoryId: categoryId,
                        amountMinor: signedMinor,
                        currencyCode: currency,
                        txnDate: localDate.yyyymmdd,
                        note: trimmedNote.isEmpty ? nil : trimmedNote,
                        createdAt: txnTimestamp,
                        updatedAt: now
                    )
                    try TransactionRepository.upsertTransaction(in: db, transaction: txn)
                }
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTransaction() {
        guard case let .edit(row) = mode else { return }
        do {
            try database.write { db in
                try TransactionRepository.deleteTransaction(in: db, transactionId: row.id)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadCategories() {
        guard categories.isEmpty else { return }
        do {
            categories = try database.read { db in
                try OrdinatioCore.Category
                    .filter(OrdinatioCore.Category.Columns.householdId == householdId)
                    .filter(OrdinatioCore.Category.Columns.deletedAt == nil)
                    .order(OrdinatioCore.Category.Columns.sortOrder.asc)
                    .fetchAll(db)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OrdinatioColor.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, OrdinatioMetric.screenPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 10)

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
            .toolbar(.hidden, for: .navigationBar)
            .animation(.easeInOut(duration: 0.20), value: focusedField)
            .task { loadCategories() }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerSheet(categories: categories, selection: $categoryId)
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerSheet(selection: $currencyCode)
                    .onDisappear { normalizeAmountTextForCurrency() }
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
            .alert("Error", isPresented: Binding(get: {
                errorMessage != nil
            }, set: { newValue in
                if !newValue { errorMessage = nil }
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(OrdinatioColor.textPrimary)
                    .frame(width: 40, height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(OrdinatioColor.surface)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(OrdinatioColor.separator.opacity(0.8), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Picker("Type", selection: $isExpense) {
                Text("Expense").tag(true)
                Text("Income").tag(false)
            }
            .pickerStyle(.segmented)

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
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(OrdinatioColor.textPrimary)
                    .frame(width: 40, height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(OrdinatioColor.surface)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(OrdinatioColor.separator.opacity(0.8), lineWidth: 1)
                    }
            }
            .accessibilityLabel("More")
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
                            .strokeBorder(OrdinatioCategoryVisuals.color(for: selectedCategoryName).opacity(0.30), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Category")
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabledIfAvailable()
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
                .disabled(MoneyFormat.fractionDigits(for: currencyCode) == 0)

            keypadButton(title: "0", role: .secondary) { appendDigit(0) }

            keypadButton(systemImage: "checkmark", role: .primary) { save() }
                .disabled(!canSave)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keypad")
    }

    private func keypadNumberRow(_ digits: [Int]) -> some View {
        ForEach(digits, id: \.self) { digit in
            keypadButton(title: "\(digit)", role: .secondary) { appendDigit(digit) }
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
        let name = Locale.current.localizedString(forCurrencyCode: code) ?? code
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let symbol = formatter.currencySymbol ?? code
        return "\(code) — \(name) (\(symbol))"
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

private extension View {
    @ViewBuilder
    func scrollClipDisabledIfAvailable() -> some View {
        if #available(iOS 17.0, *) {
            scrollClipDisabled()
        } else {
            self
        }
    }
}
