import OrdinatioCore

struct TransactionSection: Identifiable, Hashable, Sendable {
    var date: LocalDate
    var rows: [TransactionListRow]
    var netTotalMinor: Int64?

    var id: Int32 { date.yyyymmdd }
}
