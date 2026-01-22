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
}

enum OrdinatioCategoryVisuals {
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
            light: UIColor(white: 0.97, alpha: 1),
            dark: .black
        )
    }

    static var ordinatioSurface: UIColor {
        ordinatioDynamic(
            light: .white,
            dark: UIColor(white: 0.10, alpha: 1)
        )
    }

    static var ordinatioSurfaceElevated: UIColor {
        ordinatioDynamic(
            light: UIColor(white: 0.93, alpha: 1),
            dark: UIColor(white: 0.14, alpha: 1)
        )
    }

    static var ordinatioTextPrimary: UIColor {
        ordinatioDynamic(light: .black, dark: .white)
    }

    static var ordinatioTextSecondary: UIColor {
        ordinatioDynamic(
            light: UIColor(white: 0.40, alpha: 1),
            dark: UIColor(white: 0.70, alpha: 1)
        )
    }

    static var ordinatioSeparator: UIColor {
        ordinatioDynamic(
            light: UIColor(white: 0.86, alpha: 1),
            dark: UIColor(white: 0.20, alpha: 1)
        )
    }

    static var ordinatioIncome: UIColor {
        UIColor(red: 0.07, green: 0.78, blue: 0.45, alpha: 1)
    }

    static var ordinatioExpense: UIColor {
        UIColor(red: 0.95, green: 0.23, blue: 0.24, alpha: 1)
    }
}
