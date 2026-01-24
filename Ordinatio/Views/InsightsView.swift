import SwiftUI

struct InsightsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    summaryGrid
                    chartPlaceholder
                }
                .padding(OrdinatioMetric.screenPadding)
            }
            .background(OrdinatioColor.background)
            .navigationTitle("Insights")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This Week")
                .font(.headline)
                .foregroundStyle(OrdinatioColor.textSecondary)

            Text("Coming soon")
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .foregroundStyle(OrdinatioColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            summaryTile(title: "Spent/day", value: "—", symbol: "flame.fill", tint: .orange)
            summaryTile(title: "Income", value: "—", symbol: "arrow.down.circle.fill", tint: OrdinatioColor.income)
            summaryTile(title: "Expenses", value: "—", symbol: "arrow.up.circle.fill", tint: OrdinatioColor.expense)
            summaryTile(title: "Net", value: "—", symbol: "equal.circle.fill", tint: .blue)
        }
    }

    private func summaryTile(title: String, value: String, symbol: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            OrdinatioIconTile(symbolName: symbol, color: tint, size: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textSecondary)

                Text(value)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(OrdinatioColor.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: OrdinatioMetric.cardCornerRadius, style: .continuous)
                .fill(OrdinatioColor.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: OrdinatioMetric.cardCornerRadius, style: .continuous)
                .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
        }
    }

    private var chartPlaceholder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Breakdown")
                .font(.headline)
                .foregroundStyle(OrdinatioColor.textPrimary)

            RoundedRectangle(cornerRadius: OrdinatioMetric.cardCornerRadius, style: .continuous)
                .fill(OrdinatioColor.surface)
                .frame(height: 220)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                        Text("Charts land next")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: OrdinatioMetric.cardCornerRadius, style: .continuous)
                        .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
                }
        }
    }
}
