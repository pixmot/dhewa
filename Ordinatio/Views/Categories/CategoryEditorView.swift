import OrdinatioCore
import SwiftUI

struct CategoryEditorView: View {
    enum Mode: Hashable {
        case create
        case edit(OrdinatioCore.Category)
    }

    let mode: Mode
    let onSave: (String, Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @Namespace private var selectionAnimation

    @State private var name: String
    @State private var selectedIconIndex: Int?

    init(mode: Mode, onSave: @escaping (String, Int?) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _selectedIconIndex = State(initialValue: nil)
        case .edit(let category):
            _name = State(initialValue: category.name)
            _selectedIconIndex = State(initialValue: category.iconIndex)
        }
    }

    private var title: String {
        switch mode {
        case .create: return "New Category"
        case .edit: return "Edit Category"
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayName: String {
        trimmedName.isEmpty ? "Category" : trimmedName
    }

    private var previewColor: Color {
        OrdinatioCategoryVisuals.color(for: displayName, iconIndex: selectedIconIndex)
    }

    private var previewSymbolName: String {
        OrdinatioCategoryVisuals.symbolName(for: displayName, iconIndex: selectedIconIndex)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    private func save() {
        let trimmed = trimmedName
        guard !trimmed.isEmpty else { return }
        onSave(trimmed, selectedIconIndex)
        dismiss()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    iconPicker
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(OrdinatioColor.background)
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if case .create = mode {
                    isNameFocused = true
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                OrdinatioIconTile(
                    symbolName: previewSymbolName,
                    color: previewColor,
                    size: 46
                )

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Category name", text: $name)
                        .textInputAutocapitalization(.words)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textPrimary)
                        .focused($isNameFocused)
                        .accessibilityIdentifier("CategoryEditorName")

                    Text("Pick an icon to make it easy to spot.")
                        .font(.system(.footnote, design: .rounded).weight(.medium))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }
            }

            BudgetComposerView.BudgetCategoryChip(
                name: displayName,
                iconIndex: selectedIconIndex,
                selected: true,
                dimmed: false,
                onTap: {}
            )
            .allowsHitTesting(false)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(OrdinatioColor.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
        }
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Icon")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(OrdinatioColor.textPrimary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 12)], spacing: 12) {
                iconTile(
                    title: "Auto",
                    symbolName: "sparkles",
                    accent: previewColor,
                    selected: selectedIconIndex == nil
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedIconIndex = nil
                    }
                }

                ForEach(0..<OrdinatioCategoryVisuals.iconCount, id: \.self) { index in
                    iconTile(
                        emoji: OrdinatioCategoryVisuals.emoji(for: index),
                        accent: OrdinatioCategoryVisuals.color(for: index),
                        selected: selectedIconIndex == index
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIconIndex = index
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func iconTile(
        title: String? = nil,
        symbolName: String? = nil,
        emoji: String? = nil,
        accent: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let accessibilityLabel = title ?? emoji ?? "Icon"
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(OrdinatioColor.surface)

                if selected {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(accent.opacity(0.9), lineWidth: 2)
                        .matchedGeometryEffect(id: "icon_selection", in: selectionAnimation)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(accent.opacity(0.08))
                        }
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
                }

                VStack(spacing: 6) {
                    if let emoji {
                        Text(emoji)
                            .font(.system(size: 24))
                    } else if let symbolName {
                        Image(systemName: symbolName)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(accent)
                    }

                    if let title {
                        Text(title)
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                    }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 56)
        }
        .buttonStyle(BudgetComposerView.BouncyButtonStyle(duration: 0.2, scale: 0.96))
        .accessibilityLabel(accessibilityLabel)
    }
}
