import SwiftUI
import OrdinatioCore

struct CategoriesView: View {
    let database: AppDatabase
    let householdId: String

    @StateObject private var viewModel: CategoriesViewModel
    @State private var showCreate = false
    @State private var editingCategory: OrdinatioCore.Category?

    init(database: AppDatabase, householdId: String) {
        self.database = database
        self.householdId = householdId
        _viewModel = StateObject(wrappedValue: CategoriesViewModel(database: database, householdId: householdId))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.categories) { category in
                    HStack(spacing: 12) {
                        OrdinatioIconTile(
                            symbolName: OrdinatioCategoryVisuals.symbolName(for: category.name),
                            color: OrdinatioCategoryVisuals.color(for: category.name),
                            size: 32
                        )

                        Text(category.name)
                            .foregroundStyle(OrdinatioColor.textPrimary)

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingCategory = category }
                    .listRowSeparator(.hidden)
                    .listRowBackground(OrdinatioColor.background)
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        viewModel.deleteCategory(categoryId: viewModel.categories[idx].id)
                    }
                }
                .onMove(perform: viewModel.move)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(OrdinatioColor.background)
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Category")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showCreate) {
                CategoryEditorView(mode: .create) { name in
                    viewModel.addCategory(name: name)
                }
            }
            .sheet(item: $editingCategory) { category in
                CategoryEditorView(mode: .edit(category)) { name in
                    viewModel.renameCategory(categoryId: category.id, name: name)
                }
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
