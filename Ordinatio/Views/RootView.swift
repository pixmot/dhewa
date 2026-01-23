import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(PreferencesKeys.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PreferencesKeys.defaultCurrencyCode) private var defaultCurrencyCode = Locale.current.currency?.identifier ?? "USD"
    @AppStorage(PreferencesKeys.activeHouseholdId) private var activeHouseholdId = ""

    @State private var bootErrorMessage: String?

    var body: some View {
        Group {
            if let bootErrorMessage {
                if #available(iOS 17.0, *) {
                    ContentUnavailableView(
                        "Unable to start",
                        systemImage: "exclamationmark.triangle",
                        description: Text(bootErrorMessage)
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Unable to start")
                            .font(.title2.weight(.semibold))
                        Text(bootErrorMessage)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            } else if hasOnboarded {
                if activeHouseholdId.isEmpty {
                    ProgressView("Loading…")
                        .task {
                            do {
                                activeHouseholdId = try appState.ensureSeedData()
                            } catch {
                                bootErrorMessage = ErrorDisplay.message(error)
                            }
                        }
                } else {
                    MainTabView(
                        database: appState.database,
                        householdId: activeHouseholdId,
                        defaultCurrencyCode: defaultCurrencyCode
                    )
                }
            } else {
                OnboardingView(
                    selectedCurrencyCode: defaultCurrencyCode,
                    onContinue: { chosenCurrency in
                        do {
                            defaultCurrencyCode = chosenCurrency
                            activeHouseholdId = try appState.ensureSeedData()
                            hasOnboarded = true
                        } catch {
                            bootErrorMessage = ErrorDisplay.message(error)
                        }
                    }
                )
            }
        }
    }
}
