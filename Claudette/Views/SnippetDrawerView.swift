import SwiftUI

struct SnippetDrawerView: View {
    let config: AppConfiguration
    let onSnippetSelected: (PromptSnippet) -> Void

    @StateObject private var viewModel: SnippetDrawerViewModel
    @State private var showingEditor = false
    @State private var editingSnippet: PromptSnippet?

    init(config: AppConfiguration, onSnippetSelected: @escaping (PromptSnippet) -> Void) {
        self.config = config
        self.onSnippetSelected = onSnippetSelected
        _viewModel = StateObject(wrappedValue: SnippetDrawerViewModel(
            store: SnippetStore(
                storageFileName: config.snippetsStorageFileName,
                logger: LoggerFactory.logger(category: "SnippetStore")
            ),
            logger: LoggerFactory.logger(category: "SnippetDrawer")
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryPicker

                if viewModel.filteredSnippets.isEmpty {
                    ContentUnavailableView(
                        "No Snippets",
                        systemImage: "text.insert",
                        description: Text("Tap + to create a custom snippet")
                    )
                } else {
                    snippetList
                }
            }
            .navigationTitle("Snippets")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search snippets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingSnippet = nil
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                viewModel.loadSnippets()
            }
            .sheet(isPresented: $showingEditor) {
                SnippetEditorView(
                    snippet: editingSnippet,
                    onSave: { snippet in
                        if editingSnippet != nil {
                            viewModel.updateSnippet(snippet)
                        } else {
                            viewModel.addSnippet(
                                label: snippet.label,
                                command: snippet.command,
                                category: snippet.category
                            )
                        }
                        showingEditor = false
                    },
                    onCancel: {
                        showingEditor = false
                    }
                )
            }
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(label: "All", category: nil)
                ForEach(SnippetCategory.allCases) { category in
                    categoryChip(label: category.rawValue, category: category)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }

    private func categoryChip(label: String, category: SnippetCategory?) -> some View {
        Button {
            viewModel.selectedCategory = category
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(viewModel.selectedCategory == category ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(viewModel.selectedCategory == category ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    private var snippetList: some View {
        List {
            ForEach(viewModel.filteredSnippets) { snippet in
                Button {
                    onSnippetSelected(snippet)
                } label: {
                    HStack {
                        Image(systemName: snippet.category.systemImage)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.label)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(snippet.command)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if snippet.isBuiltIn {
                            Text("Built-in")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if !snippet.isBuiltIn {
                        Button(role: .destructive) {
                            viewModel.deleteSnippet(snippet)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            editingSnippet = snippet
                            showingEditor = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
    }
}
