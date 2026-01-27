import OrdinatioCore
import SwiftUI

struct TransactionRowView: View {
    let row: TransactionListRow

    private var categoryTitle: String {
        row.categoryName?.isEmpty == false ? (row.categoryName ?? "") : "Uncategorized"
    }

    private var categoryEmoji: String {
        OrdinatioCategoryVisuals.emoji(for: categoryTitle, iconIndex: row.categoryIconIndex)
    }

    private var categoryColor: Color {
        OrdinatioCategoryVisuals.color(for: categoryTitle, iconIndex: row.categoryIconIndex)
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
        return OrdinatioColor.textPrimary
    }

    private var amountText: String {
        let absMinor = row.amountMinor.ordinatioSafeAbs
        let formatted = MoneyFormat.format(minorUnits: absMinor, currencyCode: row.currencyCode)
        if row.amountMinor > 0 { return "+\(formatted)" }
        if row.amountMinor < 0 { return "-\(formatted)" }
        return formatted
    }

    var body: some View {
        HStack(spacing: 12) {
            OrdinatioEmojiTile(emoji: categoryEmoji, color: categoryColor)
                .fixedSize(horizontal: true, vertical: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(titleText)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textPrimary)
                    .lineLimit(1)

                Text(subtitleText)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text(amountText)
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(amountColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

private struct OrdinatioEmojiTile: View {
    let emoji: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(color.opacity(0.73))

            Text(emoji)
                .font(.system(.title3))
                .padding(8)
                .accessibilityHidden(true)
        }
        .opacity(0.95)
    }
}

private extension Int64 {
    var ordinatioSafeAbs: Int64 {
        self == .min ? .max : Swift.abs(self)
    }
}
