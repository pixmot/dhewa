import SwiftUI

struct OnboardingView: View {
    var selectedCurrencyCode: String
    var onContinue: (String) -> Void

    enum Step {
        case welcome
        case currency
    }

    @State private var step: Step = .welcome
    @State private var currencyCode: String
    @State private var searchText = ""

    init(selectedCurrencyCode: String, onContinue: @escaping (String) -> Void) {
        self.selectedCurrencyCode = selectedCurrencyCode
        self.onContinue = onContinue
        _currencyCode = State(initialValue: selectedCurrencyCode)
    }

    private struct Feature: Hashable {
        let symbolName: String
        let title: String
        let subtitle: String
    }

    private var features: [Feature] {
        [
            Feature(
                symbolName: "bolt.fill",
                title: "Fast by default",
                subtitle: "Designed to feel instant for everyday entry."
            ),
            Feature(
                symbolName: "lock.fill",
                title: "Offline-first",
                subtitle: "Your data stays on-device and works without a network."
            ),
            Feature(
                symbolName: "chart.bar.xaxis",
                title: "Clarity over clutter",
                subtitle: "Insights and budgets that are simple, readable, and useful."
            ),
        ]
    }

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
        let name = Locale.current.localizedString(forCurrencyCode: code) ?? code
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        let symbol = formatter.currencySymbol ?? code
        return "\(code) — \(name) (\(symbol))"
    }

    var body: some View {
        ZStack {
            OrdinatioColor.background
                .ignoresSafeArea()

            Group {
                switch step {
                case .welcome:
                    welcomeStep
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                case .currency:
                    currencyStep
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var welcomeStep: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            OrdinatioIconTile(
                symbolName: "square.grid.2x2.fill",
                color: OrdinatioCategoryVisuals.color(for: "Ordinatio"),
                size: 76
            )
            .padding(.bottom, 18)

            VStack(spacing: 8) {
                Text("Ordinatio")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                    .foregroundStyle(OrdinatioColor.textPrimary)

                Text("A simple, offline-first finance tracker.")
                    .font(.body)
                    .foregroundStyle(OrdinatioColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(features, id: \.self) { feature in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: feature.symbolName)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                            .frame(width: 26, alignment: .leading)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.title)
                                .font(.headline)
                                .foregroundStyle(OrdinatioColor.textPrimary)

                            Text(feature.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(OrdinatioColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.top, 26)
            .padding(.horizontal, 6)

            Spacer(minLength: 24)

            Button {
                step = .currency
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .foregroundStyle(OrdinatioColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(OrdinatioColor.textPrimary)
                    }
            }

            Spacer(minLength: 16)
        }
        .padding(OrdinatioMetric.screenPadding)
    }

    private var currencyStep: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    step = .welcome
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(OrdinatioColor.textPrimary)
                        .frame(width: 40, height: 40)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(OrdinatioColor.surface)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(OrdinatioColor.separator.opacity(0.8), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                VStack(alignment: .leading, spacing: 2) {
                    Text("Default Currency")
                        .font(.headline)
                        .foregroundStyle(OrdinatioColor.textPrimary)
                    Text("You can change this later.")
                        .font(.subheadline)
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }

                Spacer(minLength: 0)

                Button("Continue") {
                    onContinue(currencyCode)
                }
                .font(.headline)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, OrdinatioMetric.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 10)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(OrdinatioColor.textSecondary)

                TextField("Search currencies", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(OrdinatioColor.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(OrdinatioColor.separator.opacity(0.7), lineWidth: 1)
            }
            .padding(.horizontal, OrdinatioMetric.screenPadding)
            .padding(.bottom, 10)

            List {
                ForEach(currencyCodes, id: \.self) { code in
                    Button {
                        currencyCode = code
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

                            if currencyCode == code {
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
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}
