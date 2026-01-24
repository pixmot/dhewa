import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(PreferencesKeys.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PreferencesKeys.defaultCurrencyCode) private var defaultCurrencyCode = Locale.current.currency?.identifier ?? "USD"
    @AppStorage(PreferencesKeys.activeHouseholdId) private var activeHouseholdId = ""

    @State private var bootErrorMessage: String?

    var body: some View {
        Group {
            if let bootErrorMessage {
                ContentUnavailableView(
                    "Unable to start",
                    systemImage: "exclamationmark.triangle",
                    description: Text(bootErrorMessage)
                )
            } else if hasOnboarded {
                if activeHouseholdId.isEmpty {
                    ProgressView("Loading…")
                        .task {
                            do {
                                activeHouseholdId = try await appState.ensureSeedData()
                            } catch {
                                bootErrorMessage = ErrorDisplay.message(error)
                            }
                        }
                } else {
                    MainTabView(
                        database: appState.database,
                        db: appState.db,
                        householdId: activeHouseholdId,
                        defaultCurrencyCode: defaultCurrencyCode
                    )
                }
            } else {
                OnboardingView(
                    selectedCurrencyCode: defaultCurrencyCode,
                    onContinue: { chosenCurrency in
                        defaultCurrencyCode = chosenCurrency
                        Task { @MainActor in
                            do {
                                activeHouseholdId = try await appState.ensureSeedData()
                                hasOnboarded = true
                            } catch {
                                bootErrorMessage = ErrorDisplay.message(error)
                            }
                        }
                    }
                )
            }
        }
    }
}
