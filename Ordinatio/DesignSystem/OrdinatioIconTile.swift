import SwiftUI

struct OrdinatioIconTile: View {
    let symbolName: String
    let color: Color
    var size: CGFloat = 34

    private var cornerRadius: CGFloat { size * 0.30 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.95),
                            color.opacity(0.70),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 0.6)
                }

            Image(systemName: symbolName)
                .font(.system(size: size * 0.52, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .imageScale(.medium)
                .accessibilityHidden(true)
        }
        .frame(width: size, height: size)
    }
}

