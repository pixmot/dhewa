import Observation
import SwiftUI
import OrdinatioCore

struct BudgetsView: View {
    let db: DatabaseClient
    let householdId: String
    let defaultCurrencyCode: String

    @State private var model: BudgetComposerHostModel

    @State private var composerRoute: BudgetComposerRoute?
    @State private var composerDetent: PresentationDetent = .fraction(0.9)

    init(db: DatabaseClient, householdId: String, defaultCurrencyCode: String) {
        self.db = db
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        _model = State(initialValue: BudgetComposerHostModel(db: db, householdId: householdId))
    }

    private func presentComposer() {
        composerDetent = .fraction(0.9)
        composerRoute = .create(overallExists: model.overallExists)
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ZStack {
                OrdinatioColor.background
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    Text("Budgets")
                        .font(.system(.title, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .foregroundStyle(OrdinatioColor.textSecondary)

                        Text("Budgets are under construction")
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(OrdinatioColor.textPrimary)

                        Text("You can still create budgets. Budget tracking and insights will return soon.")
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(OrdinatioColor.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                    }
                    .padding(.bottom, 50)

                    Spacer()
                }
                .padding(.top, 20)
                .padding(.horizontal, 30)
            }
            .overlay(alignment: .bottomTrailing) {
                BudgetCreateButton {
                    presentComposer()
                }
                .padding(.trailing, 20)
                .padding(.bottom, 12)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $composerRoute) { route in
                BudgetComposerView(
                    route: route,
                    db: db,
                    householdId: householdId,
                    categories: model.categories,
                    existingCategoryBudgetIds: model.existingCategoryBudgetIds,
                    defaultCurrencyCode: defaultCurrencyCode,
                    onSave: { model.upsertBudget(from: $0) }
                )
                .presentationDetents([.fraction(0.9), .large], selection: $composerDetent)
                .presentationDragIndicator(.visible)
            }
            .alert("Error", isPresented: Binding(get: {
                model.errorMessage != nil
            }, set: { newValue in
                if !newValue { model.errorMessage = nil }
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }
}

private struct BudgetCreateButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Create Budget", systemImage: "plus")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(OrdinatioColor.textPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(LiquidGlassCapsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create Budget")
    }
}

enum BudgetComposerRoute: Identifiable {
    case create(overallExists: Bool)

    var id: String {
        switch self {
        case let .create(overallExists):
            return "create_\(overallExists ? 1 : 0)"
        }
    }

    var overallExists: Bool {
        switch self {
        case let .create(overallExists):
            return overallExists
        }
    }
}

@MainActor
@Observable
private final class BudgetComposerHostModel {
    var budgets: [Budget] = []
    var categories: [OrdinatioCore.Category] = []
    var errorMessage: String?

    private let db: DatabaseClient
    private let householdId: String

    @ObservationIgnored private var budgetsTask: Task<Void, Never>?
    @ObservationIgnored private var categoriesTask: Task<Void, Never>?

    init(db: DatabaseClient, householdId: String) {
        self.db = db
        self.householdId = householdId

        startObservingBudgets()
        startObservingCategories()
    }

    deinit {
        budgetsTask?.cancel()
        categoriesTask?.cancel()
    }

    var overallExists: Bool {
        budgets.contains(where: { $0.isOverall })
    }

    var existingCategoryBudgetIds: Set<String> {
        Set(budgets.compactMap(\.categoryId))
    }

    func upsertBudget(from draft: BudgetDraft) {
        Task { @MainActor in
            do {
                try await db.upsertBudget(
                    householdId: householdId,
                    isOverall: draft.isOverall,
                    categoryId: draft.categoryId,
                    timeFrame: draft.timeFrame,
                    startDate: draft.startDate,
                    currencyCode: draft.currencyCode,
                    amountMinor: draft.amountMinor
                )
            } catch {
                errorMessage = ErrorDisplay.message(error)
            }
        }
    }

    private func startObservingBudgets() {
        budgetsTask?.cancel()

        let db = db
        let householdId = householdId

        budgetsTask = Task.detached(priority: .userInitiated) { [db, householdId] in
            do {
                for try await budgets in await db.observeBudgets(householdId: householdId) {
                    await MainActor.run { [weak self] in
                        self?.budgets = budgets
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = ErrorDisplay.message(error)
                }
            }
        }
    }

    private func startObservingCategories() {
        categoriesTask?.cancel()

        let db = db
        let householdId = householdId

        categoriesTask = Task.detached(priority: .userInitiated) { [db, householdId] in
            do {
                for try await categories in await db.observeCategories(householdId: householdId) {
                    await MainActor.run { [weak self] in
                        self?.categories = categories
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = ErrorDisplay.message(error)
                }
            }
        }
    }
}
