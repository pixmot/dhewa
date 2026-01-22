import Combine
import Foundation
import OrdinatioCore

@MainActor
final class CategoriesViewModel: ObservableObject {
    @Published private(set) var categories: [OrdinatioCore.Category] = []
    @Published var errorMessage: String?

    private let database: AppDatabase
    private let householdId: String

    private var categoriesCancellable: AnyCancellable?

    init(database: AppDatabase, householdId: String) {
        self.database = database
        self.householdId = householdId
        startObserving()
    }

    private func startObserving() {
        categoriesCancellable?.cancel()
        categoriesCancellable = CategoryRepository
            .observeCategories(householdId: householdId)
            .publisher(in: database.dbQueue)
            .sink { [weak self] completion in
                if case let .failure(error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] categories in
                self?.categories = categories
            }
    }

    func addCategory(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try database.write { db in
                _ = try CategoryRepository.createCategory(in: db, householdId: householdId, name: trimmed)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameCategory(categoryId: String, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try database.write { db in
                try CategoryRepository.updateCategoryName(in: db, categoryId: categoryId, name: trimmed)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCategory(categoryId: String) {
        do {
            try database.write { db in
                try CategoryRepository.deleteCategory(in: db, categoryId: categoryId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        var updated = categories
        updated.move(fromOffsets: source, toOffset: destination)
        let orderedIds = updated.map(\.id)
        do {
            try database.write { db in
                try CategoryRepository.reorderCategories(in: db, householdId: householdId, orderedCategoryIds: orderedIds)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
