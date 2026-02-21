import Foundation

enum ClaudeResourceType: String, Codable, Sendable {
    case command
    case skill
    case agent

    var displayTitle: String {
        switch self {
        case .command: return "Commands"
        case .skill: return "Skills"
        case .agent: return "Agents"
        }
    }

    var icon: String {
        switch self {
        case .command: return "terminal"
        case .skill: return "star"
        case .agent: return "cpu"
        }
    }

    var directoryName: String {
        switch self {
        case .command: return "commands"
        case .skill: return "skills"
        case .agent: return "agents"
        }
    }
}

struct ClaudeResource: Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let type: ClaudeResourceType
    let description: String?
    let isUserInvocable: Bool
    let filePath: String

    var displayName: String {
        name.replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }

    /// The bare slug stripped of `.md` and any directory prefix.
    private var slug: String {
        name.replacingOccurrences(of: ".md", with: "")
    }

    /// Display label shown in the UI (e.g. `/commit` or `librarian-agent`).
    var invokeCommand: String {
        switch type {
        case .command, .skill:
            return "/" + slug
        case .agent:
            return slug
        }
    }

    /// The actual text sent to the terminal when triggered.
    /// Commands/skills send a slash command; agents send a natural-language
    /// prompt so Claude Code spawns them via the Task tool.
    var triggerCommand: String {
        switch type {
        case .command, .skill:
            return invokeCommand
        case .agent:
            if let description, !description.isEmpty {
                return "Run the \(slug) agent: \(description)"
            }
            return "Run the \(slug) agent"
        }
    }
}
