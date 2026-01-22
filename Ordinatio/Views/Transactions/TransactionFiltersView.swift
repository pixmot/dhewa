import SwiftUI
import OrdinatioCore

struct TransactionFiltersView: View {
    let categories: [OrdinatioCore.Category]
    let availableCurrencyCodes: [String]
    let defaultCurrencyCode: String

    var currentFilter: TransactionFilter
    var onApply: (TransactionFilter) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategoryId: String?
    @State private var selectedCurrencyCode: String?
    @State private var minAmountText: String
    @State private var maxAmountText: String
    @State private var errorMessage: String?

    init(
        categories: [OrdinatioCore.Category],
        availableCurrencyCodes: [String],
        defaultCurrencyCode: String,
        currentFilter: TransactionFilter,
        onApply: @escaping (TransactionFilter) -> Void
    ) {
        self.categories = categories
        self.availableCurrencyCodes = availableCurrencyCodes
        self.defaultCurrencyCode = defaultCurrencyCode
        self.currentFilter = currentFilter
        self.onApply = onApply

        _selectedCategoryId = State(initialValue: currentFilter.categoryId)
        _selectedCurrencyCode = State(initialValue: currentFilter.currencyCode)
        _minAmountText = State(initialValue: "")
        _maxAmountText = State(initialValue: "")
    }

    private var currencyOptions: [String] {
        var set = Set(availableCurrencyCodes.map { $0.uppercased() })
        set.insert(defaultCurrencyCode.uppercased())
        return Array(set).sorted()
    }

    private func apply() {
        errorMessage = nil

        let trimmedMin = minAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMax = maxAmountText.trimmingCharacters(in: .whitespacesAndNewlines)

        let needsCurrency = !trimmedMin.isEmpty || !trimmedMax.isEmpty
        let effectiveCurrency = (selectedCurrencyCode?.uppercased())
            ?? (needsCurrency ? defaultCurrencyCode.uppercased() : nil)

        func parse(_ text: String) -> Int64? {
            guard let effectiveCurrency else { return nil }
            switch MoneyFormat.parseMinorUnits(text, currencyCode: effectiveCurrency) {
            case let .success(minor): return abs(minor)
            case .failure:
                return nil
            }
        }

        var minMinor: Int64?
        if !trimmedMin.isEmpty {
            guard let parsed = parse(trimmedMin) else {
                errorMessage = "Invalid minimum amount"
                return
            }
            minMinor = parsed
        }

        var maxMinor: Int64?
        if !trimmedMax.isEmpty {
            guard let parsed = parse(trimmedMax) else {
                errorMessage = "Invalid maximum amount"
                return
            }
            maxMinor = parsed
        }

        if let minMinor, let maxMinor, minMinor > maxMinor {
            errorMessage = "Minimum amount must be ≤ maximum amount"
            return
        }

        var next = currentFilter
        next.categoryId = selectedCategoryId
        next.currencyCode = effectiveCurrency
        next.minAbsAmountMinor = minMinor
        next.maxAbsAmountMinor = maxMinor

        onApply(next)
        dismiss()
    }

    private func clear() {
        selectedCategoryId = nil
        selectedCurrencyCode = nil
        minAmountText = ""
        maxAmountText = ""
        errorMessage = nil
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

                Section("Category") {
                    Picker("Category", selection: $selectedCategoryId) {
                        Text("All").tag(String?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(String?.some(category.id))
                        }
                    }
                }

                Section("Currency") {
                    Picker("Currency", selection: $selectedCurrencyCode) {
                        Text("Any").tag(String?.none)
                        ForEach(currencyOptions, id: \.self) { code in
                            Text(code).tag(String?.some(code))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Min amount", text: $minAmountText)
                            .keyboardType(.decimalPad)
                        TextField("Max amount", text: $maxAmountText)
                            .keyboardType(.decimalPad)
                        Text("Tip: amount range applies to the selected currency.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Member (Coming Soon)") {
                    HStack {
                        Text("Member")
                        Spacer()
                        Text("Not available yet")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { clear() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }
                }
            }
        }
    }
}
