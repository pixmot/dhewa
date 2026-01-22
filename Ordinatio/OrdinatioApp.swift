import SwiftUI
import OrdinatioCore

@main
struct OrdinatioApp: App {
    @StateObject private var appState: AppState

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
        if isUITesting {
            UserDefaults.standard.set(true, forKey: PreferencesKeys.hasOnboarded)
            UserDefaults.standard.removeObject(forKey: PreferencesKeys.activeHouseholdId)
            UserDefaults.standard.set("USD", forKey: PreferencesKeys.defaultCurrencyCode)
        }

        let database: AppDatabase
        do {
            database = try AppDatabase(databaseURL: DatabasePaths.appDatabaseURL())
            if isUITesting {
                try database.resetAllData()
            }
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
        _appState = StateObject(wrappedValue: AppState(database: database))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
