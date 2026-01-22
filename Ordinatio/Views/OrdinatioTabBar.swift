import SwiftUI

enum OrdinatioTab: Hashable {
    case log
    case insights
    case budgets
    case settings

    var title: String {
        switch self {
        case .log: return "Log"
        case .insights: return "Insights"
        case .budgets: return "Budgets"
        case .settings: return "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .log: return "list.bullet"
        case .insights: return "chart.bar.xaxis"
        case .budgets: return "square.grid.2x2"
        case .settings: return "gearshape"
        }
    }
}

struct OrdinatioTabBar: View {
    @Binding var selection: OrdinatioTab
    var onAdd: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.log)
            tabButton(.insights)
            addButton
            tabButton(.budgets)
            tabButton(.settings)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: OrdinatioMetric.tabBarCornerRadius, style: .continuous)
                .fill(OrdinatioColor.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: OrdinatioMetric.tabBarCornerRadius, style: .continuous)
                .strokeBorder(OrdinatioColor.separator.opacity(0.9), lineWidth: 1)
        }
        .shadow(
            color: colorScheme == .dark ? .clear : .black.opacity(0.10),
            radius: 18,
            x: 0,
            y: 10
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab Bar")
    }

    private func tabButton(_ tab: OrdinatioTab) -> some View {
        Button {
            selection = tab
        } label: {
            Image(systemName: tab.symbolName)
                .symbolVariant(selection == tab ? .fill : .none)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(selection == tab ? OrdinatioColor.textPrimary : OrdinatioColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: OrdinatioMetric.tabBarHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selection == tab ? .isSelected : [])
    }

    private var addButton: some View {
        Button(action: onAdd) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OrdinatioColor.textPrimary)
                .frame(width: 56, height: 36)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(OrdinatioColor.background)
                        .accessibilityLabel("Add Transaction")
                }
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

