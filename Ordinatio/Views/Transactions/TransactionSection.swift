import OrdinatioCore

struct TransactionSection: Identifiable, Hashable {
    var date: LocalDate
    var rows: [TransactionListRow]

    var id: Int32 { date.yyyymmdd }
}

