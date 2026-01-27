import OrdinatioCore
import SwiftUI

struct TransactionRowView: View {
    let row: TransactionListRow

    private var categoryTitle: String {
        row.categoryName?.isEmpty == false ? (row.categoryName ?? "") : "Uncategorized"
    }

    private var titleText: String {
        if let note = row.note, !note.isEmpty { return note }
        return categoryTitle
    }

    private var subtitleText: String {
        let time = row.createdAt.formatted(date: .omitted, time: .shortened)
        if let note = row.note, !note.isEmpty {
            return "\(categoryTitle) · \(time)"
        }
        return time
    }

    private var amountColor: Color {
        if row.amountMinor > 0 { return OrdinatioColor.income }
        if row.amountMinor < 0 { return OrdinatioColor.expense }
        return OrdinatioColor.textSecondary
    }

    private var amountText: String {
        let absMinor = row.amountMinor.ordinatioSafeAbs
        let formatted = MoneyFormat.format(minorUnits: absMinor, currencyCode: row.currencyCode)
        if row.amountMinor > 0 { return "+\(formatted)" }
        if row.amountMinor < 0 { return "-\(formatted)" }
        return formatted
    }

    var body: some View {
        HStack(spacing: 10) {
            OrdinatioIconTile(
                symbolName: OrdinatioCategoryVisuals.symbolName(
                    for: categoryTitle,
                    iconIndex: row.categoryIconIndex
                ),
                color: OrdinatioCategoryVisuals.color(for: categoryTitle, iconIndex: row.categoryIconIndex),
                size: 28
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textPrimary)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.caption2)
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text(amountText)
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

private extension Int64 {
    var ordinatioSafeAbs: Int64 {
        self == .min ? .max : Swift.abs(self)
    }
}
