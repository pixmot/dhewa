import OrdinatioCore
import SwiftUI

struct TransactionRowView: View {
    let row: TransactionListRow

    private var categoryTitle: String {
        row.categoryName?.isEmpty == false ? (row.categoryName ?? "") : "Uncategorized"
    }

    private var amountColor: Color {
        row.amountMinor < 0 ? OrdinatioColor.expense : OrdinatioColor.income
    }

    var body: some View {
        HStack(spacing: 10) {
            OrdinatioIconTile(
                symbolName: OrdinatioCategoryVisuals.symbolName(
                    for: categoryTitle,
                    iconIndex: row.categoryIconIndex
                ),
                color: OrdinatioCategoryVisuals.color(for: categoryTitle, iconIndex: row.categoryIconIndex),
                size: 30
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(categoryTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textPrimary)

                if let note = row.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(OrdinatioColor.textSecondary)
                        .lineLimit(1)
                } else {
                    Text(row.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Text(MoneyFormat.format(minorUnits: row.amountMinor, currencyCode: row.currencyCode))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 4)
    }
}
