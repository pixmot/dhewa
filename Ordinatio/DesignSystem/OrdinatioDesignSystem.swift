import SwiftUI

enum OrdinatioMetric {
    static let screenPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let iconTileCornerRadius: CGFloat = 10
    static let tabBarCornerRadius: CGFloat = 18
    static let tabBarHeight: CGFloat = 56
    static let tabBarHorizontalPadding: CGFloat = 14
}

enum OrdinatioColor {
    static var background: Color { Color(uiColor: .ordinatioBackground) }
    static var surface: Color { Color(uiColor: .ordinatioSurface) }
    static var surfaceElevated: Color { Color(uiColor: .ordinatioSurfaceElevated) }

    static var textPrimary: Color { Color(uiColor: .ordinatioTextPrimary) }
    static var textSecondary: Color { Color(uiColor: .ordinatioTextSecondary) }

    static var separator: Color { Color(uiColor: .ordinatioSeparator) }

    static var income: Color { Color(uiColor: .ordinatioIncome) }
    static var expense: Color { Color(uiColor: .ordinatioExpense) }

    static var darkBackground: Color { Color(uiColor: .ordinatioDarkBackground) }
    static var lightIcon: Color { Color(uiColor: .ordinatioLightIcon) }

    static var actionBlue: Color { Color(red: 0.416, green: 0.486, blue: 0.976) }
    static var actionOrange: Color { Color(red: 0.992, green: 0.737, blue: 0.231) }
}

enum OrdinatioCategoryVisuals {
    static func emoji(for categoryName: String) -> String {
        let emojis = [
            "🛒",
            "🍽️",
            "☕️",
            "🏠",
            "🚗",
            "🚌",
            "✈️",
            "🚆",
            "❤️",
            "🩺",
            "🎓",
            "🎮",
            "🎁",
            "🎬",
            "👕",
            "🐾",
            "🌿",
            "⚡️",
            "🛍️",
            "💳",
            "💵",
            "🎵",
            "📚",
            "✨",
        ]

        let index = categoryName.ordinatioStableHash % emojis.count
        return emojis[index]
    }

    static func symbolName(for categoryName: String) -> String {
        let symbols = [
            "cart.fill",
            "fork.knife",
            "cup.and.saucer.fill",
            "house.fill",
            "car.fill",
            "bus.fill",
            "airplane",
            "train.side.front.car",
            "heart.fill",
            "cross.case.fill",
            "graduationcap.fill",
            "gamecontroller.fill",
            "gift.fill",
            "film.fill",
            "tshirt.fill",
            "pawprint.fill",
            "leaf.fill",
            "bolt.fill",
            "bag.fill",
            "creditcard.fill",
            "dollarsign.circle.fill",
            "music.note",
            "book.fill",
            "sparkles",
        ]

        let index = categoryName.ordinatioStableHash % symbols.count
        return symbols[index]
    }

    static func color(for categoryName: String) -> Color {
        let palette = [
            Color(red: 0.16, green: 0.60, blue: 0.96),
            Color(red: 0.93, green: 0.48, blue: 0.35),
            Color(red: 0.67, green: 0.40, blue: 0.64),
            Color(red: 0.77, green: 0.41, blue: 0.97),
            Color(red: 0.43, green: 0.48, blue: 0.95),
            Color(red: 0.95, green: 0.75, blue: 0.34),
            Color(red: 0.93, green: 0.50, blue: 0.64),
            Color(red: 0.91, green: 0.30, blue: 0.39),
            Color(red: 0.38, green: 0.78, blue: 0.98),
            Color(red: 0.42, green: 0.69, blue: 0.63),
            Color(red: 0.95, green: 0.66, blue: 0.54),
            Color(red: 0.37, green: 0.69, blue: 0.84),
        ]

        let index = categoryName.ordinatioStableHash % palette.count
        return palette[index]
    }
}

/// A pill-shaped, "liquid glass" material background used for primary pill actions.
struct LiquidGlassCapsule: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Capsule(style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.18 : 0.55),
                        lineWidth: 1
                    )
            )
            .overlay(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.45),
                                Color.white.opacity(0.08),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.12),
                radius: 10,
                x: 0,
                y: 6
            )
    }
}

extension View {
    @ViewBuilder
    func ordinatioRoundedFontDesign() -> some View {
        if #available(iOS 16.1, *) {
            fontDesign(.rounded)
        } else {
            self
        }
    }
}

private extension String {
    var ordinatioStableHash: Int {
        unicodeScalars.reduce(0) { partialResult, scalar in
            (partialResult &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
    }
}

private extension UIColor {
    static func ordinatioDynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    }

    static var ordinatioBackground: UIColor {
        ordinatioDynamic(
            light: .white,
            dark: UIColor(red: 0.024, green: 0.039, blue: 0.028, alpha: 1)
        )
    }

    static var ordinatioSurface: UIColor {
        ordinatioDynamic(
            light: .white,
            dark: UIColor(red: 0.137, green: 0.149, blue: 0.149, alpha: 1)
        )
    }

    static var ordinatioSurfaceElevated: UIColor {
        ordinatioDynamic(
            light: UIColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1),
            dark: UIColor(red: 0.227, green: 0.227, blue: 0.235, alpha: 1)
        )
    }

    static var ordinatioTextPrimary: UIColor {
        ordinatioDynamic(
            light: UIColor(red: 0.004, green: 0.004, blue: 0.004, alpha: 1),
            dark: .white
        )
    }

    static var ordinatioTextSecondary: UIColor {
        ordinatioDynamic(
            light: UIColor(red: 0.651, green: 0.651, blue: 0.651, alpha: 1),
            dark: UIColor(red: 0.463, green: 0.463, blue: 0.463, alpha: 1)
        )
    }

    static var ordinatioSeparator: UIColor {
        ordinatioDynamic(
            light: UIColor(red: 0.925, green: 0.941, blue: 0.957, alpha: 1),
            dark: UIColor(red: 0.180, green: 0.180, blue: 0.180, alpha: 1)
        )
    }

    static var ordinatioIncome: UIColor {
        UIColor(red: 0.07, green: 0.78, blue: 0.45, alpha: 1)
    }

    static var ordinatioExpense: UIColor {
        UIColor(red: 0.95, green: 0.23, blue: 0.24, alpha: 1)
    }

    static var ordinatioDarkBackground: UIColor {
        ordinatioDynamic(
            light: UIColor(red: 0.235, green: 0.235, blue: 0.235, alpha: 1),
            dark: .white
        )
    }

    static var ordinatioLightIcon: UIColor {
        ordinatioDynamic(
            light: .white,
            dark: UIColor(red: 0.137, green: 0.149, blue: 0.149, alpha: 1)
        )
    }
}
