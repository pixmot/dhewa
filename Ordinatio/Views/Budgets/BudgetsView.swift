import Combine
import Foundation
import SwiftUI
import OrdinatioCore

struct BudgetsView: View {
    let database: AppDatabase
    let householdId: String
    let defaultCurrencyCode: String

    @StateObject private var viewModel: BudgetComposerHostViewModel

    @State private var composerRoute: BudgetComposerRoute?
    @State private var composerDetent: PresentationDetent = .fraction(0.9)

    init(database: AppDatabase, householdId: String, defaultCurrencyCode: String) {
        self.database = database
        self.householdId = householdId
        self.defaultCurrencyCode = defaultCurrencyCode
        _viewModel = StateObject(wrappedValue: BudgetComposerHostViewModel(database: database, householdId: householdId))
    }

    private func presentComposer() {
        composerDetent = .fraction(0.9)
        composerRoute = .create(overallExists: viewModel.overallExists)
    }

    var body: some View {
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
                    database: database,
                    householdId: householdId,
                    categories: viewModel.categories,
                    existingCategoryBudgetIds: viewModel.existingCategoryBudgetIds,
                    defaultCurrencyCode: defaultCurrencyCode,
                    onSave: { viewModel.upsertBudget(from: $0) }
                )
                .presentationDetents([.fraction(0.9), .large], selection: $composerDetent)
                .presentationDragIndicator(.visible)
            }
            .alert("Error", isPresented: Binding(get: {
                viewModel.errorMessage != nil
            }, set: { newValue in
                if !newValue { viewModel.errorMessage = nil }
            })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
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
private final class BudgetComposerHostViewModel: ObservableObject {
    @Published private(set) var budgets: [Budget] = []
    @Published private(set) var categories: [OrdinatioCore.Category] = []
    @Published var errorMessage: String?

    private let database: AppDatabase
    private let householdId: String

    private var budgetsCancellable: AnyCancellable?
    private var categoriesCancellable: AnyCancellable?

    init(database: AppDatabase, householdId: String) {
        self.database = database
        self.householdId = householdId

        startObservingBudgets()
        startObservingCategories()
    }

    var overallExists: Bool {
        budgets.contains(where: { $0.isOverall })
    }

    var existingCategoryBudgetIds: Set<String> {
        Set(budgets.compactMap(\.categoryId))
    }

    func upsertBudget(from draft: BudgetDraft) {
        do {
            try database.write { db in
                try BudgetRepository.upsertBudget(
                    in: db,
                    householdId: householdId,
                    isOverall: draft.isOverall,
                    categoryId: draft.categoryId,
                    timeFrame: draft.timeFrame,
                    startDate: draft.startDate,
                    currencyCode: draft.currencyCode,
                    amountMinor: draft.amountMinor
                )
            }
        } catch {
            errorMessage = ErrorDisplay.message(error)
        }
    }

    private func startObservingBudgets() {
        budgetsCancellable?.cancel()
        budgetsCancellable = BudgetRepository
            .observeBudgets(householdId: householdId)
            .publisher(in: database.dbQueue)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = ErrorDisplay.message(error)
                }
            } receiveValue: { [weak self] budgets in
                self?.budgets = budgets
            }
    }

    private func startObservingCategories() {
        categoriesCancellable?.cancel()
        categoriesCancellable = CategoryRepository
            .observeCategories(householdId: householdId)
            .publisher(in: database.dbQueue)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = ErrorDisplay.message(error)
                }
            } receiveValue: { [weak self] categories in
                self?.categories = categories
            }
    }
}
