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
                Section {
                    if viewModel.categories.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(.largeTitle, design: .rounded).weight(.light))
                                .foregroundStyle(OrdinatioColor.textSecondary)

                            Text("No categories yet.")
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundStyle(OrdinatioColor.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                        .listRowBackground(OrdinatioColor.surfaceElevated)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.categories) { category in
                            HStack(spacing: 10) {
                                Text(OrdinatioCategoryVisuals.emoji(for: category.name))
                                    .font(.system(.subheadline, design: .rounded))

                                Text(category.name)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(OrdinatioColor.textPrimary)
                                    .lineLimit(1)

                                Spacer(minLength: 0)

                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(OrdinatioCategoryVisuals.color(for: category.name))
                                    .frame(width: 20, height: 20)
                            }
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                            .onTapGesture { editingCategory = category }
                            .listRowBackground(OrdinatioColor.surfaceElevated)
                            .listRowSeparatorTint(OrdinatioColor.separator)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteCategory(categoryId: category.id)
                                } label: {
                                    Image(systemName: "trash.fill")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingCategory = category
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .tint(OrdinatioColor.actionOrange)
                            }
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                viewModel.deleteCategory(categoryId: viewModel.categories[idx].id)
                            }
                        }
                        .onMove(perform: viewModel.move)
                    }
                } header: {
                    Text("CATEGORIES")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(OrdinatioColor.textSecondary)
                }
            }
            .listStyle(.insetGrouped)
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
