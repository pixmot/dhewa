import SwiftUI
import OrdinatioCore

struct SettingsView: View {
    let database: AppDatabase
    let householdId: String

    @AppStorage(PreferencesKeys.hasOnboarded) private var hasOnboarded = false
    @AppStorage(PreferencesKeys.activeHouseholdId) private var activeHouseholdId = ""

    @State private var showResetConfirm = false
    @State private var showCategories = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    private func export() {
        do {
            exportURL = try ExportService.exportTransactionsCSV(database: database, householdId: householdId)
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reset() {
        do {
            try database.resetAllData()
            activeHouseholdId = ""
            hasOnboarded = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    settingsRow(
                        title: "Categories",
                        symbol: "tag.fill",
                        tint: OrdinatioCategoryVisuals.color(for: "Categories")
                    ) {
                        showCategories = true
                    }
                } header: {
                    Text("Manage")
                }

                Section {
                    settingsRow(
                        title: "Export Transactions",
                        symbol: "square.and.arrow.up",
                        tint: OrdinatioCategoryVisuals.color(for: "Export")
                    ) {
                        export()
                    }

                    settingsRow(
                        title: "Reset All Data",
                        symbol: "trash.fill",
                        tint: OrdinatioColor.expense,
                        isDestructive: true
                    ) {
                        showResetConfirm = true
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Reset deletes all local households, categories, transactions, and budgets.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(OrdinatioColor.background)
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset all data?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) { reset() }
            }
            .sheet(isPresented: $showShareSheet) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .sheet(isPresented: $showCategories) {
                CategoriesView(database: database, householdId: householdId)
            }
            .alert("Error", isPresented: Binding(get: {
                errorMessage != nil
            }, set: { newValue in
                if !newValue { errorMessage = nil }
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func settingsRow(
        title: String,
        symbol: String,
        tint: Color,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                OrdinatioIconTile(symbolName: symbol, color: tint, size: 30)

                Text(title)
                    .foregroundStyle(isDestructive ? OrdinatioColor.expense : OrdinatioColor.textPrimary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OrdinatioColor.textSecondary)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}
