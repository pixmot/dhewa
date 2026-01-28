import Foundation
import OrdinatioCore
import SwiftUI

extension TransactionEditorView {
    struct TransactionChip: View {
        let label: String
        let systemImage: String
        let tint: Color
        let expands: Bool
        let minHeight: CGFloat?
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(tint)

                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: expands ? .infinity : nil, alignment: .leading)
                .frame(minHeight: minHeight, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OrdinatioColor.surface)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    struct CategoryPickerSheet: View {
        let db: DatabaseClient
        let householdId: String
        let kind: CategoryKind
        @Binding var categories: [OrdinatioCore.Category]
        @Binding var selection: String?

        @Environment(\.dismiss) private var dismiss
        @State private var showingCategoryCreator = false
        @State private var errorMessage: String?
        @State private var searchText = ""
        @State private var scrollViewportHeight: CGFloat = 0
        @State private var flowLayoutHeight: CGFloat = 0
        @State private var detentSelection: PresentationDetent = .height(Layout.minDetentHeight)

        private enum Layout {
            static let flowSpacing: CGFloat = 10
            static let flowPadding: CGFloat = 15
            static let addButtonSize: CGFloat = 46
            static let addButtonPadding: CGFloat = 16
            static let bottomInset: CGFloat = addButtonSize + (addButtonPadding * 2)
            static let bottomAnchorId = "category_bottom"
            static let sheetChromeHeight: CGFloat = 220
            static let minDetentHeight: CGFloat = 360
            static let maxDetentHeight: CGFloat = 680
            static let maxTopSpacer: CGFloat = 24
        }

        private struct ScrollViewportHeightKey: PreferenceKey {
            static var defaultValue: CGFloat = 0
            static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
                value = max(value, nextValue())
            }
        }

        private struct FlowLayoutHeightKey: PreferenceKey {
            static var defaultValue: CGFloat = 0
            static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
                value = max(value, nextValue())
            }
        }

        private var availableCategoryOptions: [OrdinatioCore.Category] {
            categories.filter { $0.kind == kind }
        }

        private var emptyState: (icon: String, message: String)? {
            availableCategoryOptions.isEmpty ? (icon: "tray.full.fill", message: emptyStateMessage) : nil
        }

        private var emptyStateMessage: String {
            switch kind {
            case .expense:
                return "No expense\ncategories yet."
            case .income:
                return "No income\ncategories yet."
            }
        }

        private var filteredCategoryOptions: [OrdinatioCore.Category] {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return availableCategoryOptions }
            return availableCategoryOptions.filter { $0.name.lowercased().contains(query) }
        }

        private var topSpacerHeight: CGFloat {
            let available = scrollViewportHeight - (flowLayoutHeight + Layout.bottomInset)
            return max(0, min(available, Layout.maxTopSpacer))
        }

        private var preferredDetentHeight: CGFloat? {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard query.isEmpty else { return nil }
            guard flowLayoutHeight > 0 else { return nil }

            let height = flowLayoutHeight + Layout.sheetChromeHeight
            return min(max(height, Layout.minDetentHeight), Layout.maxDetentHeight)
        }

        private var heightDetent: PresentationDetent {
            .height(preferredDetentHeight ?? Layout.minDetentHeight)
        }

        private var detents: Set<PresentationDetent> {
            [heightDetent, .large]
        }

        private struct ScrollToBottomTaskID: Equatable {
            var optionCount: Int
            var isSearchEmpty: Bool
        }

        private func emptyStateView(icon: String, message: String) -> some View {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(OrdinatioColor.textSecondary.opacity(0.7))
                    .padding(.top, 20)

                Text(message)
                    .font(.system(.title3, design: .rounded).weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(OrdinatioColor.textSecondary.opacity(0.7))
                    .padding(.bottom, 20)
            }
            .frame(maxHeight: .infinity)
        }

        private var categoryScrollView: some View {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: topSpacerHeight)

                        BudgetComposerView.FlowLayout(spacing: Layout.flowSpacing) {
                            ForEach(filteredCategoryOptions) { category in
                                BudgetComposerView.BudgetCategoryChip(
                                    category: category,
                                    selected: selection == category.id,
                                    dimmed: selection != nil && selection != category.id
                                ) {
                                    if selection == category.id {
                                        selection = nil
                                    } else {
                                        selection = category.id
                                    }
                                    dismiss()
                                }
                            }
                        }
                        .padding(Layout.flowPadding)
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: FlowLayoutHeightKey.self,
                                    value: geometry.size.height
                                )
                            }
                        }

                        Color.clear
                            .frame(height: Layout.bottomInset)
                            .id(Layout.bottomAnchorId)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollViewportHeightKey.self,
                            value: geometry.size.height
                        )
                    }
                }
                .task(
                    id: ScrollToBottomTaskID(
                        optionCount: filteredCategoryOptions.count,
                        isSearchEmpty: searchText.isEmpty
                    )
                ) {
                    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard query.isEmpty else { return }
                    await Task.yield()
                    try? await Task.sleep(for: .milliseconds(80))
                    proxy.scrollTo(Layout.bottomAnchorId, anchor: .bottom)
                }
                .onPreferenceChange(ScrollViewportHeightKey.self) { scrollViewportHeight = $0 }
                .onPreferenceChange(FlowLayoutHeightKey.self) { flowLayoutHeight = $0 }
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
        }

        private var addCategoryButton: some View {
            Button {
                showingCategoryCreator = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(OrdinatioColor.textPrimary)
                    .frame(width: Layout.addButtonSize, height: Layout.addButtonSize)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Circle()
                                    .strokeBorder(OrdinatioColor.separator.opacity(0.6), lineWidth: 1)
                            }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create Category")
            .accessibilityIdentifier("CategoryAddButton")
        }

        @ViewBuilder
        private var sheetContent: some View {
            VStack(spacing: 12) {
                if let emptyState {
                    emptyStateView(icon: emptyState.icon, message: emptyState.message)
                } else {
                    categoryScrollView
                }
            }
        }

        var body: some View {
            NavigationStack {
                sheetContent
                    .padding(20)
                    .background(OrdinatioColor.background)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .cancel) {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Close")
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        addCategoryButton
                            .padding(.trailing, Layout.addButtonPadding)
                            .padding(.bottom, Layout.addButtonPadding)
                    }
                    .searchable(text: $searchText, prompt: "Search categories")
                    .presentationDetents(detents, selection: $detentSelection)
                    .presentationContentInteraction(.scrolls)
                    .presentationDragIndicator(.visible)
                    .sheet(isPresented: $showingCategoryCreator) {
                        CategoryEditorView(mode: .create) { name, iconIndex in
                            createCategory(name: name, iconIndex: iconIndex)
                        }
                    }
                    .alert(
                        "Couldn't create category",
                        isPresented: Binding(
                            get: { errorMessage != nil },
                            set: { newValue in if !newValue { errorMessage = nil } }
                        )
                    ) {
                        Button("OK", role: .cancel) {}
                    }
            }
            .onAppear {
                detentSelection = heightDetent
            }
            .onChange(of: heightDetent) { _, newValue in
                if detentSelection != .large {
                    detentSelection = newValue
                }
            }
        }

        private func createCategory(name: String, iconIndex: Int?) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            Task { @MainActor in
                do {
                    let created = try await db.createCategory(
                        householdId: householdId,
                        kind: kind,
                        name: trimmed,
                        iconIndex: iconIndex
                    )
                    categories.append(created)
                    categories.sort {
                        if $0.kind != $1.kind {
                            return $0.kind.rawValue < $1.kind.rawValue
                        }
                        return $0.sortOrder < $1.sortOrder
                    }
                } catch {
                    errorMessage = "Couldn't create category"
                }
            }
        }
    }

    struct CurrencyPickerSheet: View {
        @Binding var selection: String

        @Environment(\.dismiss) private var dismiss
        @State private var searchText = ""

        private struct CurrencyOptionRow: View {
            let code: String
            let name: String
            let symbol: String
            let accent: Color
            let selected: Bool
            let onTap: () -> Void

            private var shape: RoundedRectangle {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
            }

            var body: some View {
                Button(action: onTap) {
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text(code)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(accent)

                            Text(symbol)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(OrdinatioColor.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(accent.opacity(0.12), in: Capsule(style: .continuous))

                        Text(name)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(OrdinatioColor.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 0)

                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(selected ? accent : OrdinatioColor.separator)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(shape.fill(OrdinatioColor.surface))
                    .overlay {
                        shape.strokeBorder(
                            selected ? accent.opacity(0.65) : OrdinatioColor.separator.opacity(0.75),
                            lineWidth: selected ? 2 : 1
                        )
                    }
                    .overlay {
                        if selected {
                            shape.fill(accent.opacity(0.06))
                        }
                    }
                    .contentShape(shape)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }

        private static let currencySymbolCache: [String: String] = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = .current

            var cache: [String: String] = [:]
            for code in Locale.commonISOCurrencyCodes {
                let upper = code.uppercased()
                formatter.currencyCode = upper
                cache[upper] = formatter.currencySymbol ?? upper
            }
            return cache
        }()

        private var currencyCodes: [String] {
            let all = Locale.commonISOCurrencyCodes
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return all }
            return all.filter { code in
                let name = Locale.current.localizedString(forCurrencyCode: code) ?? ""
                return code.lowercased().contains(query) || name.lowercased().contains(query)
            }
        }

        private func currencyTitle(_ code: String) -> String {
            let upper = code.uppercased()
            let name = Locale.current.localizedString(forCurrencyCode: upper) ?? upper
            let symbol = Self.currencySymbolCache[upper] ?? upper
            return "\(upper) — \(name) (\(symbol))"
        }

        private func currencyRow(code: String) -> some View {
            let upper = code.uppercased()
            return CurrencyOptionRow(
                code: upper,
                name: Locale.current.localizedString(forCurrencyCode: upper) ?? upper,
                symbol: Self.currencySymbolCache[upper] ?? upper,
                accent: OrdinatioCategoryVisuals.color(for: upper),
                selected: selection.uppercased() == upper,
                onTap: {
                    selection = upper
                    dismiss()
                }
            )
            .accessibilityIdentifier("currency.\(upper)")
            .accessibilityLabel(currencyTitle(upper))
        }

        var body: some View {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(currencyCodes, id: \.self) { code in
                            currencyRow(code: code)
                        }
                    }
                    .padding(.horizontal, OrdinatioMetric.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.immediately)
                .scrollIndicators(.hidden)
                .background(OrdinatioColor.background)
                .navigationTitle("Currency")
                .searchable(text: $searchText, prompt: "Search currencies")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    struct DateTimePickerSheet: View {
        enum PickerStyle {
            case graphical
            case wheel
        }

        let title: String
        @Binding var selection: Date
        let displayedComponents: DatePickerComponents
        let style: PickerStyle

        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    Group {
                        switch style {
                        case .graphical:
                            DatePicker(title, selection: $selection, displayedComponents: displayedComponents)
                                .datePickerStyle(.graphical)
                        case .wheel:
                            DatePicker(title, selection: $selection, displayedComponents: displayedComponents)
                                .datePickerStyle(.wheel)
                        }
                    }
                    .labelsHidden()
                    .padding(.horizontal, OrdinatioMetric.screenPadding)
                    .padding(.top, 10)

                    Spacer(minLength: 0)
                }
                .background(OrdinatioColor.background)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    struct DateAndTimePickerSheet: View {
        @Binding var selection: Date

        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                VStack(spacing: 0) {
                    DatePicker("Date", selection: $selection, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(.horizontal, OrdinatioMetric.screenPadding)
                        .padding(.top, 10)

                    DatePicker("Time", selection: $selection, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding(.horizontal, OrdinatioMetric.screenPadding)

                    Spacer(minLength: 0)

                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .foregroundStyle(OrdinatioColor.background)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(OrdinatioColor.textPrimary)
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, OrdinatioMetric.screenPadding)
                    .padding(.bottom, 16)
                    .accessibilityIdentifier("DateAndTimeDoneButton")
                }
                .background(OrdinatioColor.background)
                .navigationTitle("Date & Time")
            }
            .presentationDetents([.large])
        }
    }
}
