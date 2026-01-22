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

    @State private var categories: [OrdinatioCore.Category] = []
    @State private var isExpense: Bool
    @State private var amountText: String
    @State private var currencyCode: String
    @State private var date: Date
    @State private var categoryId: String?
    @State private var note: String
    @State private var errorMessage: String?
    @State private var confirmDelete = false

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
            _date = State(initialValue: Date())
            _categoryId = State(initialValue: nil)
            _note = State(initialValue: "")
        case let .edit(row):
            _isExpense = State(initialValue: row.amountMinor < 0)
            _amountText = State(initialValue: Self.entryAmountText(absMinor: abs(row.amountMinor), currencyCode: row.currencyCode))
            _currencyCode = State(initialValue: row.currencyCode.uppercased())
            _date = State(initialValue: LocalDate(yyyymmdd: row.txnDate).date())
            _categoryId = State(initialValue: row.categoryId)
            _note = State(initialValue: row.note ?? "")
        }
    }

    static func entryAmountText(absMinor: Int64, currencyCode: String) -> String {
        let decimal = MoneyFormat.decimal(fromMinorUnits: absMinor, currencyCode: currencyCode)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
        formatter.maximumFractionDigits = MoneyFormat.fractionDigits(for: currencyCode)
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? ""
    }

    private var title: String {
        switch mode {
        case .create: return "New Transaction"
        case .edit: return "Edit Transaction"
        }
    }

    private func save() {
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

        let signedMinor = isExpense ? -abs(absMinor) : abs(absMinor)
        let localDate = LocalDate.from(date: date)
        let now = Date()
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
                        createdAt: now,
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
                        createdAt: row.createdAt,
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
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Type") {
                    Picker("Type", selection: $isExpense) {
                        Text("Expense").tag(true)
                        Text("Income").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Details") {
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityIdentifier("TransactionAmountField")
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Category") {
                    Picker("Category", selection: $categoryId) {
                        Text("Uncategorized").tag(String?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(String?.some(category.id))
                        }
                    }
                }

                Section("Note") {
                    TextField("Optional note", text: $note, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .accessibilityIdentifier("TransactionNoteField")
                }

                if case .edit = mode {
                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Delete Transaction")
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete this transaction?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteTransaction()
                }
            }
        }
        .task { loadCategories() }
    }
}
