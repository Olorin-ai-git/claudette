import Foundation
import os

protocol SnippetStoreProtocol: Sendable {
    func loadSnippets() -> [PromptSnippet]
    func saveSnippets(_ snippets: [PromptSnippet]) throws
}

final class SnippetStore: SnippetStoreProtocol, @unchecked Sendable {
    private let fileURL: URL
    private let logger: Logger
    private let queue = DispatchQueue(label: "com.olorin.claudette.snippetstore")

    init(storageFileName: String, logger: Logger) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("com.olorin.claudette")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent(storageFileName)
        self.logger = logger
    }

    func loadSnippets() -> [PromptSnippet] {
        queue.sync {
            var snippets = loadDefaultSnippets()

            if let data = try? Data(contentsOf: fileURL) {
                let decoder = JSONDecoder()
                if let userSnippets = try? decoder.decode([PromptSnippet].self, from: data) {
                    let userCustom = userSnippets.filter { !$0.isBuiltIn }
                    snippets.append(contentsOf: userCustom)
                }
            }

            return snippets
        }
    }

    func saveSnippets(_ snippets: [PromptSnippet]) throws {
        try queue.sync {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snippets)
            try data.write(to: fileURL, options: .atomic)
            logger.info("Saved \(snippets.count) snippets")
        }
    }

    private func loadDefaultSnippets() -> [PromptSnippet] {
        guard let url = Bundle.main.url(forResource: "DefaultSnippets", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            logger.warning("DefaultSnippets.json not found in bundle")
            return []
        }

        let decoder = JSONDecoder()
        guard let snippets = try? decoder.decode([PromptSnippet].self, from: data) else {
            logger.error("Failed to decode DefaultSnippets.json")
            return []
        }

        return snippets
    }
}
