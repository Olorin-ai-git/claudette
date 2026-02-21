import Foundation
import os

protocol TmuxSessionServiceProtocol: Sendable {
    func sessionName(profileId: UUID, prefix: String) -> String
    func checkTmuxCommand() -> String
    func hasSessionCommand(sessionName: String) -> String
    func attachCommand(sessionName: String) -> String
    func newSessionCommand(sessionName: String, directory: String, initialCommand: String) -> String
    func attachOrCreateCommand(sessionName: String, directory: String, initialCommand: String) -> String
}

struct TmuxSessionService: TmuxSessionServiceProtocol {
    func sessionName(profileId: UUID, prefix: String) -> String {
        let shortId = String(profileId.uuidString.prefix(8)).lowercased()
        return prefix + "-" + shortId
    }

    func checkTmuxCommand() -> String {
        "which tmux"
    }

    func hasSessionCommand(sessionName: String) -> String {
        "tmux has-session -t " + shellEscape(sessionName) + " 2>/dev/null"
    }

    func attachCommand(sessionName: String) -> String {
        "tmux attach-session -t " + shellEscape(sessionName)
    }

    func newSessionCommand(sessionName: String, directory: String, initialCommand: String) -> String {
        "tmux new-session -s " + shellEscape(sessionName) +
            " -c " + shellEscape(directory) +
            " " + shellEscape(initialCommand)
    }

    func attachOrCreateCommand(sessionName: String, directory: String, initialCommand: String) -> String {
        let tmuxBranch =
            "tmux has-session -t " + shellEscape(sessionName) + " 2>/dev/null && " +
            attachCommand(sessionName: sessionName) + " || " +
            newSessionCommand(sessionName: sessionName, directory: directory, initialCommand: initialCommand)

        let directFallback =
            "cd " + shellEscape(directory) + " && exec " + shellEscape(initialCommand)

        // If tmux is not installed fall back to a plain cd + exec
        return "(command -v tmux >/dev/null 2>&1 && (" + tmuxBranch + ")) || (" + directFallback + ")"
    }

    private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
