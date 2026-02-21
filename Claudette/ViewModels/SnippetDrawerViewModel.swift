import Foundation
import os

@MainActor
final class SnippetDrawerViewModel: ObservableObject {
    @Published var snippets: [PromptSnippet] = []
    @Published var selectedCategory: SnippetCategory?
    @Published var searchText: String = ""

    private let store: SnippetStoreProtocol
    private let logger: Logger

    init(store: SnippetStoreProtocol, logger: Logger) {
        self.store = store
        self.logger = logger
    }

    var filteredSnippets: [PromptSnippet] {
        var result = snippets

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.label.lowercased().contains(query) ||
                    $0.command.lowercased().contains(query)
            }
        }

        return result
    }

    func loadSnippets() {
        snippets = store.loadSnippets()
        let count = snippets.count
        logger.info("Loaded \(count) snippets")
    }

    func addSnippet(label: String, command: String, category: SnippetCategory) {
        let snippet = PromptSnippet(
            label: label,
            command: command,
            category: category,
            isBuiltIn: false
        )
        snippets.append(snippet)
        saveUserSnippets()
    }

    func deleteSnippet(_ snippet: PromptSnippet) {
        guard !snippet.isBuiltIn else { return }
        snippets.removeAll { $0.id == snippet.id }
        saveUserSnippets()
    }

    func updateSnippet(_ snippet: PromptSnippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index] = snippet
        saveUserSnippets()
    }

    private func saveUserSnippets() {
        do {
            try store.saveSnippets(snippets.filter { !$0.isBuiltIn })
        } catch {
            logger.error("Failed to save snippets: \(error.localizedDescription)")
        }
    }
}
