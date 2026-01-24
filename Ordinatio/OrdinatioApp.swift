import OrdinatioCore
import SwiftUI
import os

@main
struct OrdinatioApp: App {
    @State private var appState: AppState?
    @State private var startupErrorMessage: String?

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        if isUITesting {
            UserDefaults.standard.set(true, forKey: PreferencesKeys.hasOnboarded)
            UserDefaults.standard.removeObject(forKey: PreferencesKeys.activeHouseholdId)
            UserDefaults.standard.set("USD", forKey: PreferencesKeys.defaultCurrencyCode)
        }

        do {
            let database = try AppDatabase(databaseURL: DatabasePaths.appDatabaseURL())
            if isUITesting {
                try database.resetAllData()
            }
            _appState = State(initialValue: AppState(database: database))
            _startupErrorMessage = State(initialValue: nil)
        } catch {
            OrdinatioLog.database.error(
                "Failed to initialize database: \(String(describing: error), privacy: .public)"
            )
            _appState = State(initialValue: nil)
            _startupErrorMessage = State(initialValue: ErrorDisplay.message(error))
        }
    }

    var body: some Scene {
        WindowGroup {
            if let appState {
                RootView()
                    .environment(appState)
            } else {
                StartupErrorView(message: startupErrorMessage ?? "Unable to start.")
            }
        }
    }
}

private struct StartupErrorView: View {
    let message: String

    var body: some View {
        ZStack {
            OrdinatioColor.background
                .ignoresSafeArea()

            ContentUnavailableView(
                "Unable to start",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            .padding(OrdinatioMetric.screenPadding)
        }
    }
}
