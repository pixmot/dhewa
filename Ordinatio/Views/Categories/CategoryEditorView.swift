import OrdinatioCore
import SwiftUI

struct CategoryEditorView: View {
    enum Mode: Hashable {
        case create
        case edit(OrdinatioCore.Category)
    }

    let mode: Mode
    var onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(mode: Mode, onSave: @escaping (String) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .create:
            _name = State(initialValue: "")
        case .edit(let category):
            _name = State(initialValue: category.name)
        }
    }

    private var title: String {
        switch mode {
        case .create: return "New Category"
        case .edit: return "Edit Category"
        }
    }

    private func save() {
        onSave(name)
        dismiss()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
