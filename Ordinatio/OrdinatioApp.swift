import OrdinatioCore
import SwiftUI

@main
struct OrdinatioApp: App {
    @State private var appState: AppState

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
        _appState = State(initialValue: AppState(database: database))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}
