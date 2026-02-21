import SwiftUI

struct SnippetEditorView: View {
    let snippet: PromptSnippet?
    let onSave: (PromptSnippet) -> Void
    let onCancel: () -> Void

    @State private var label: String
    @State private var command: String
    @State private var category: SnippetCategory

    init(
        snippet: PromptSnippet?,
        onSave: @escaping (PromptSnippet) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.snippet = snippet
        self.onSave = onSave
        self.onCancel = onCancel
        _label = State(initialValue: snippet?.label ?? "")
        _command = State(initialValue: snippet?.command ?? "")
        _category = State(initialValue: snippet?.category ?? .custom)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Label", text: $label)
                        .autocorrectionDisabled()

                    Picker("Category", selection: $category) {
                        ForEach(SnippetCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }

                Section("Command") {
                    TextEditor(text: $command)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle(snippet == nil ? "New Snippet" : "Edit Snippet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let result = PromptSnippet(
                            id: snippet?.id ?? UUID(),
                            label: label.trimmingCharacters(in: .whitespaces),
                            command: command,
                            category: category,
                            isBuiltIn: false
                        )
                        onSave(result)
                    }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty || command.isEmpty)
                }
            }
        }
    }
}
