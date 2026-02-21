import Foundation

struct TerminalBlock: Sendable {
    let startLine: Int
    let endLine: Int
    let content: String
}

/// Detects Claude Code response blocks from terminal output text.
/// Block boundaries are identified by shell/Claude prompt patterns.
struct TerminalBlockDetector: Sendable {
    private static let promptSuffixes: [String] = [
        "$ ",
        "% ",
        "# ",
        "> ",
    ]

    static func isPromptLine(_ line: String) -> Bool {
        let stripped = stripANSI(line).trimmingCharacters(in: .whitespaces)
        guard !stripped.isEmpty else { return false }
        return promptSuffixes.contains { stripped.hasSuffix($0) }
    }

    /// Find the block containing the given line index within the provided lines array.
    static func detectBlock(lines: [String], atLine lineIndex: Int) -> TerminalBlock? {
        guard lineIndex < lines.count else { return nil }

        // Search upward for block start (stop at prompt line above)
        var startLine = lineIndex
        while startLine > 0 {
            if isPromptLine(lines[startLine - 1]) {
                break
            }
            startLine -= 1
        }

        // Search downward for block end (stop before next prompt)
        var endLine = lineIndex
        while endLine < lines.count - 1 {
            if isPromptLine(lines[endLine + 1]) {
                break
            }
            endLine += 1
        }

        let blockLines = Array(lines[startLine ... endLine])
        let content = blockLines.joined(separator: "\n")

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return TerminalBlock(startLine: startLine, endLine: endLine, content: content)
    }

    static func stripANSI(_ text: String) -> String {
        var result = text
        while let range = result.range(of: "\u{1B}\\[[0-9;]*[a-zA-Z]", options: .regularExpression) {
            result.removeSubrange(range)
        }
        return result
    }
}
