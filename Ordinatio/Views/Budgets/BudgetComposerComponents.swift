import Foundation
import OrdinatioCore
import SwiftUI

extension BudgetComposerView {
    struct BudgetTypeRow: View {
        let title: String
        let selected: Bool
        let animation: Namespace.ID
        var onTap: () -> Void

        var body: some View {
            HStack {
                Text(title)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(.callout, design: .rounded).weight(.medium))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(OrdinatioColor.textPrimary)
            .font(.system(.title3, design: .rounded).weight(.medium))
            .padding(8)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(OrdinatioColor.surfaceElevated)
                        .matchedGeometryEffect(id: "budget_picker", in: animation)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
        }
    }

    struct BudgetTypeBlock: View {
        let title: String
        let subtitle: String
        let symbol: String
        let accent: Color
        let selected: Bool
        var onTap: () -> Void

        private var cardShape: RoundedRectangle {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
        }

        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(selected ? 0.2 : 0.12))

                        Image(systemName: symbol)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 52, height: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(OrdinatioColor.textPrimary)

                        Text(subtitle)
                            .font(.system(.footnote, design: .rounded).weight(.medium))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                    }

                    Spacer()

                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(selected ? accent : OrdinatioColor.textSecondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                .background(cardShape.fill(OrdinatioColor.surfaceElevated))
                .overlay {
                    cardShape
                        .strokeBorder(
                            selected ? accent.opacity(0.6) : OrdinatioColor.separator,
                            lineWidth: selected ? 2 : 1
                        )
                }
                .overlay {
                    if selected {
                        cardShape
                            .fill(accent.opacity(0.08))
                    }
                }
                .contentShape(cardShape)
            }
            .buttonStyle(BouncyButtonStyle(duration: 0.2, scale: 0.98))
        }
    }

    struct BudgetCategoryChip: View {
        let category: OrdinatioCore.Category
        let selected: Bool
        let dimmed: Bool
        var onTap: () -> Void

        private var name: String { category.name }
        private var emoji: String { OrdinatioCategoryVisuals.emoji(for: name) }
        private var color: Color { OrdinatioCategoryVisuals.color(for: name) }

        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 5) {
                    Text(emoji)
                        .font(.system(.subheadline, design: .rounded))
                    Text(name)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? color : OrdinatioColor.textPrimary)
                .background(
                    selected ? color.opacity(0.35) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    if !selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(OrdinatioColor.separator, lineWidth: 1.5)
                    }
                }
                .opacity(dimmed ? 0.4 : 1)
            }
            .buttonStyle(BouncyButtonStyle(duration: 0.2, scale: 0.8))
        }
    }

    struct BudgetPickerStyle: ViewModifier {
        var colorScheme: ColorScheme

        func body(content: Content) -> some View {
            content
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(OrdinatioColor.background)
                        .shadow(color: colorScheme == .light ? OrdinatioColor.separator : Color.clear, radius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(
                            colorScheme == .light ? Color.clear : OrdinatioColor.separator.opacity(0.4),
                            lineWidth: 1.3
                        )
                )
                .frame(maxWidth: .infinity)
        }
    }

    struct BudgetStepProgress: View {
        let currentStep: Int
        let totalSteps: Int
        let accent: Color
        let track: Color

        private var clampedTotal: Int {
            max(totalSteps, 1)
        }

        private var clampedCurrent: Int {
            min(max(currentStep, 1), clampedTotal)
        }

        var body: some View {
            HStack(spacing: 6) {
                ForEach(1...clampedTotal, id: \.self) { step in
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(step <= clampedCurrent ? accent : track.opacity(0.6))

                            if clampedTotal > 1 {
                                Text("\(step)")
                                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                                    .foregroundStyle(
                                        step <= clampedCurrent ? OrdinatioColor.lightIcon : OrdinatioColor.textSecondary
                                    )
                            }
                        }
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .strokeBorder(OrdinatioColor.separator, lineWidth: step <= clampedCurrent ? 0 : 1)
                        }

                        if step < clampedTotal {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(step < clampedCurrent ? accent.opacity(0.8) : track.opacity(0.5))
                                .frame(width: 14, height: 3)
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }

    struct BudgetNumberPadTextView: View {
        let amountMinor: Int64
        let currencyCode: String

        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        private static let currencySymbolFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = .current
            return formatter
        }()

        private static func pow10Int64(_ digits: Int) -> Int64? {
            guard digits >= 0 else { return nil }
            var value: Int64 = 1
            for _ in 0..<digits {
                let (next, overflow) = value.multipliedReportingOverflow(by: 10)
                if overflow { return nil }
                value = next
            }
            return value
        }

        private static func format(absMinor: Int64, fractionDigits: Int) -> String {
            guard let multiplier = pow10Int64(fractionDigits), multiplier > 0 else { return "" }

            if fractionDigits == 0 {
                return String(absMinor)
            }

            let whole = absMinor / multiplier
            let fraction = absMinor % multiplier
            let fractionText = String(fraction)
            let zeros = String(repeating: "0", count: max(0, fractionDigits - fractionText.count))
            return "\(whole).\(zeros)\(fractionText)"
        }

        private var currencySymbol: String {
            Self.currencySymbolFormatter.currencyCode = currencyCode.uppercased()
            return Self.currencySymbolFormatter.currencySymbol ?? currencyCode.uppercased()
        }

        var body: some View {
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(currencySymbol)
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(OrdinatioColor.textSecondary)

                Text(amountString)
                    .font(.system(size: amountFontSize, weight: .regular, design: .rounded))
                    .foregroundStyle(OrdinatioColor.textPrimary)
            }
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("BudgetAmountField")
        }

        private var amountString: String {
            let digits = MoneyFormat.fractionDigits(for: currencyCode)
            return Self.format(absMinor: abs(amountMinor), fractionDigits: digits)
        }

        private var amountFontSize: CGFloat {
            switch dynamicTypeSize {
            case .xSmall:
                return 46
            case .small:
                return 47
            case .medium:
                return 48
            case .large:
                return 50
            case .xLarge:
                return 56
            case .xxLarge:
                return 58
            case .xxxLarge:
                return 62
            default:
                return 50
            }
        }
    }

    struct BudgetNumberPad: View {
        @Binding var amountMinor: Int64
        let canSubmit: Bool
        var onSubmit: () -> Void

        private let numPadNumbers = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

        var body: some View {
            GeometryReader { proxy in
                let hSpacing = proxy.size.width * 0.05
                let vSpacing = proxy.size.height * 0.04

                let buttonWidth = proxy.size.width * 0.3
                let buttonHeight = proxy.size.height * 0.22

                VStack(spacing: vSpacing) {
                    ForEach(numPadNumbers, id: \.self) { row in
                        HStack(spacing: hSpacing) {
                            ForEach(row, id: \.self) { digit in
                                digitButton(digit, width: buttonWidth, height: buttonHeight)
                            }
                        }
                    }

                    HStack(spacing: hSpacing) {
                        deleteButton(width: buttonWidth, height: buttonHeight)

                        digitButton(0, width: buttonWidth, height: buttonHeight)

                        submitButton(width: buttonWidth, height: buttonHeight)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .padding(.bottom, 15)
        }

        private func digitButton(_ digit: Int, width: CGFloat, height: CGFloat) -> some View {
            Button {
                appendDigit(digit)
            } label: {
                Text("\(digit)")
                    .font(.system(size: 34, weight: .regular, design: .rounded))
                    .frame(width: width, height: height)
                    .background(OrdinatioColor.surfaceElevated)
                    .foregroundStyle(OrdinatioColor.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(NumPadButtonStyle())
            .accessibilityIdentifier("BudgetKeypadDigit\(digit)")
        }

        private func deleteButton(width: CGFloat, height: CGFloat) -> some View {
            Button {
                deleteDigit()
            } label: {
                Image(systemName: "delete.left")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .frame(width: width, height: height)
                    .background(OrdinatioColor.darkBackground)
                    .foregroundStyle(OrdinatioColor.lightIcon)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(NumPadButtonStyle())
            .accessibilityLabel("Backspace")
            .accessibilityIdentifier("BudgetKeypadBackspace")
        }

        private func submitButton(width: CGFloat, height: CGFloat) -> some View {
            Button {
                onSubmit()
            } label: {
                Image(systemName: "checkmark.square.fill")
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .symbolEffect(.bounce.up.byLayer, value: canSubmit)
                    .frame(width: width, height: height)
                    .foregroundStyle(OrdinatioColor.lightIcon)
                    .background(OrdinatioColor.darkBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(NumPadButtonStyle())
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.6)
            .accessibilityIdentifier("BudgetKeypadSubmit")
        }

        private func appendDigit(_ digit: Int) {
            guard (0...9).contains(digit) else { return }
            if amountMinor > (Int64.max / 10) {
                return
            }
            amountMinor = (amountMinor * 10) + Int64(digit)
        }

        private func deleteDigit() {
            amountMinor /= 10
        }
    }

    struct NumPadButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
        }
    }

    struct BouncyButtonStyle: ButtonStyle {
        let duration: Double
        let scale: CGFloat

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? scale : 1)
                .animation(.easeOut(duration: duration), value: configuration.isPressed)
        }
    }

    struct FlowLayout: Layout {
        let spacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let maxWidth = proposal.width ?? .infinity
            var currentX: CGFloat = 0
            var rowHeight: CGFloat = 0
            var totalHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth, currentX > 0 {
                    totalHeight += rowHeight + spacing
                    currentX = 0
                    rowHeight = 0
                }
                currentX += size.width + (currentX > 0 ? spacing : 0)
                rowHeight = max(rowHeight, size.height)
            }

            totalHeight += rowHeight
            return CGSize(width: maxWidth, height: totalHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var currentX = bounds.minX
            var currentY = bounds.minY
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                    currentX = bounds.minX
                    currentY += rowHeight + spacing
                    rowHeight = 0
                }

                subview.place(
                    at: CGPoint(x: currentX, y: currentY),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )

                currentX += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
    }
}
