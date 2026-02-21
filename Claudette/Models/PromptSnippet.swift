import Foundation

struct PromptSnippet: Codable, Sendable, Identifiable, Hashable {
    let id: UUID
    var label: String
    var command: String
    var category: SnippetCategory
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        label: String,
        command: String,
        category: SnippetCategory,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.label = label
        self.command = command
        self.category = category
        self.isBuiltIn = isBuiltIn
    }
}
