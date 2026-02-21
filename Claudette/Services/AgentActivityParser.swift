import Foundation
import os

@MainActor
final class AgentActivityParser: ObservableObject {
    @Published var rootNodes: [AgentTreeNode] = []
    @Published var activeAgentCount: Int = 0

    private let logger: Logger
    private var buffer: String = ""
    private var nodeStack: [AgentTreeNode] = []

    /// Regex patterns for agent spawn/completion in Claude Code output
    private static let spawnPattern = try! NSRegularExpression(
        pattern: #"(?:Launching|Spawning|Starting)\s+(\w[\w-]*)\s+agent.*?[:\u{2026}](.+?)$"#,
        options: [.anchorsMatchLines]
    )

    private static let completePattern = try! NSRegularExpression(
        pattern: #"(?:Agent|Task)\s+(\w[\w-]*)\s+(?:completed|finished|done)"#,
        options: [.caseInsensitive, .anchorsMatchLines]
    )

    private static let taskToolPattern = try! NSRegularExpression(
        pattern: #"Task\s*\(\s*(?:description|subagent_type)\s*[:=]\s*[\"']?(\w[\w\s-]*)[\"']?"#,
        options: [.anchorsMatchLines]
    )

    init(logger: Logger) {
        self.logger = logger
    }

    func processOutput(_ bytes: [UInt8]) {
        guard let text = String(bytes: bytes, encoding: .utf8) else { return }
        buffer += text

        // Process complete lines
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[buffer.startIndex ..< newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            parseLine(line)
        }
    }

    private func parseLine(_ line: String) {
        let stripped = stripANSI(line)
        let range = NSRange(stripped.startIndex ..< stripped.endIndex, in: stripped)

        // Check for agent spawn
        if let match = Self.spawnPattern.firstMatch(in: stripped, range: range) {
            let agentType = extractGroup(stripped, match: match, group: 1)
            let description = extractGroup(stripped, match: match, group: 2)
            spawnAgent(type: agentType, description: description)
            return
        }

        // Check for Task tool invocation
        if let match = Self.taskToolPattern.firstMatch(in: stripped, range: range) {
            let agentType = extractGroup(stripped, match: match, group: 1)
            spawnAgent(type: agentType, description: agentType)
            return
        }

        // Check for agent completion
        if let match = Self.completePattern.firstMatch(in: stripped, range: range) {
            let agentType = extractGroup(stripped, match: match, group: 1)
            completeAgent(type: agentType)
        }
    }

    private func spawnAgent(type: String, description: String) {
        let node = AgentTreeNode(
            id: UUID().uuidString,
            agentType: type.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces)
        )

        if let parent = nodeStack.last {
            parent.children.append(node)
        } else {
            rootNodes.append(node)
        }

        nodeStack.append(node)
        activeAgentCount += 1
        logger.debug("Agent spawned: \(type, privacy: .public)")
    }

    private func completeAgent(type: String) {
        let trimmedType = type.trimmingCharacters(in: .whitespaces)

        // Find and mark as completed (search from top of stack)
        for i in stride(from: nodeStack.count - 1, through: 0, by: -1) {
            if nodeStack[i].agentType.lowercased() == trimmedType.lowercased() {
                nodeStack[i].isCompleted = true
                nodeStack.remove(at: i)
                activeAgentCount = max(0, activeAgentCount - 1)
                logger.debug("Agent completed: \(type, privacy: .public)")
                return
            }
        }
    }

    private func extractGroup(_ string: String, match: NSTextCheckingResult, group: Int) -> String {
        guard group < match.numberOfRanges,
              let range = Range(match.range(at: group), in: string)
        else {
            return ""
        }
        return String(string[range])
    }

    private func stripANSI(_ text: String) -> String {
        var result = text
        while let range = result.range(of: "\u{1B}\\[[0-9;]*[a-zA-Z]", options: .regularExpression) {
            result.removeSubrange(range)
        }
        return result
    }

    func reset() {
        rootNodes.removeAll()
        nodeStack.removeAll()
        activeAgentCount = 0
        buffer = ""
    }
}
