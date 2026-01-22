import SwiftUI
import OrdinatioCore

enum BudgetEditorMode: Hashable {
    case create(month: YearMonth, defaultCurrencyCode: String)
    case edit(month: YearMonth, summary: CurrencyBudgetSummary)
}

struct BudgetEditorView: View {
    let mode: BudgetEditorMode
    var onSave: (String, Int64) -> Void
    var onDelete: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var currencyCode: String
    @State private var amountText: String
    @State private var errorMessage: String?
    @State private var confirmDelete = false

    init(
        mode: BudgetEditorMode,
        onSave: @escaping (String, Int64) -> Void,
        onDelete: ((String) -> Void)? = nil
    ) {
        self.mode = mode
        self.onSave = onSave
        self.onDelete = onDelete

        switch mode {
        case let .create(_, defaultCurrencyCode):
            _currencyCode = State(initialValue: defaultCurrencyCode.uppercased())
            _amountText = State(initialValue: "")
        case let .edit(_, summary):
            _currencyCode = State(initialValue: summary.currencyCode.uppercased())
            if let budgetMinor = summary.budgetMinor {
                _amountText = State(initialValue: TransactionEditorView.entryAmountText(absMinor: budgetMinor, currencyCode: summary.currencyCode))
            } else {
                _amountText = State(initialValue: "")
            }
        }
    }

    private var title: String {
        switch mode {
        case .create: return "New Budget"
        case .edit: return "Edit Budget"
        }
    }

    private var currencyPickerDisabled: Bool {
        if case .edit = mode { return true }
        return false
    }

    private func save() {
        errorMessage = nil
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Amount is required"
            return
        }

        switch MoneyFormat.parseMinorUnits(trimmed, currencyCode: currencyCode.uppercased()) {
        case let .success(minor):
            onSave(currencyCode.uppercased(), abs(minor))
            dismiss()
        case .failure:
            errorMessage = "Invalid amount"
        }
    }

    private func deleteBudget() {
        guard let onDelete else { return }
        onDelete(currencyCode.uppercased())
        dismiss()
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

                Section("Budget") {
                    Picker("Currency", selection: $currencyCode) {
                        ForEach(Locale.commonISOCurrencyCodes, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                    .disabled(currencyPickerDisabled)

                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                }

                if onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Text("Delete Budget")
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
                "Delete this budget?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteBudget() }
            }
        }
    }
}

