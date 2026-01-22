import OrdinatioCore

extension TransactionListRow: @retroactive Identifiable {}
extension CurrencyBudgetSummary: @retroactive Identifiable {
    public var id: String { currencyCode }
}
