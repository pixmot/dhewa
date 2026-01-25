import Foundation
import OrdinatioCore
import SwiftUI

extension TransactionEditorView {
    struct TransactionChip: View {
        let label: String
        let systemImage: String
        let tint: Color
        let action: () -> Void
        let expands: Bool
        let minHeight: CGFloat?

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
        let categories: [OrdinatioCore.Category]
        @Binding var selection: String?

        @Environment(\.dismiss) private var dismiss
        @State private var searchText = ""

        private var filtered: [OrdinatioCore.Category] {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !query.isEmpty else { return categories }
            return categories.filter { $0.name.lowercased().contains(query) }
        }

        var body: some View {
            NavigationStack {
                List {
                    Button {
                        selection = nil
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            OrdinatioIconTile(
                                symbolName: OrdinatioCategoryVisuals.symbolName(for: "Uncategorized"),
                                color: OrdinatioCategoryVisuals.color(for: "Uncategorized"),
                                size: 30
                            )

                            Text("Uncategorized")
                                .foregroundStyle(OrdinatioColor.textPrimary)

                            Spacer(minLength: 0)

                            if selection == nil {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(OrdinatioColor.background)

                    ForEach(filtered) { category in
                        Button {
                            selection = category.id
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                OrdinatioIconTile(
                                    symbolName: OrdinatioCategoryVisuals.symbolName(for: category.name),
                                    color: OrdinatioCategoryVisuals.color(for: category.name),
                                    size: 30
                                )

                                Text(category.name)
                                    .foregroundStyle(OrdinatioColor.textPrimary)

                                Spacer(minLength: 0)

                                if selection == category.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(OrdinatioColor.background)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(OrdinatioColor.background)
                .navigationTitle("Category")
                .searchable(text: $searchText, prompt: "Search categories")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    struct CurrencyPickerSheet: View {
        @Binding var selection: String

        @Environment(\.dismiss) private var dismiss
        @State private var searchText = ""

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

        var body: some View {
            NavigationStack {
                List {
                    ForEach(currencyCodes, id: \.self) { code in
                        Button {
                            selection = code.uppercased()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                OrdinatioIconTile(
                                    symbolName: "banknote.fill",
                                    color: OrdinatioCategoryVisuals.color(for: code),
                                    size: 30
                                )

                                Text(currencyTitle(code))
                                    .foregroundStyle(OrdinatioColor.textPrimary)

                                Spacer(minLength: 0)

                                if selection.uppercased() == code.uppercased() {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(OrdinatioColor.background)
                    }
                }
                .scrollContentBackground(.hidden)
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
                }
                .background(OrdinatioColor.background)
                .navigationTitle("Date & Time")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
