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
        let escaped = shellEscape(sessionName)
        let escapedCmd = shellEscape(initialCommand)

        // When an existing tmux session is found, check if claude is still
        // running inside it. If the process has exited (user backgrounded the
        // app and claude timed-out / crashed), send the launch command into the
        // pane so it restarts with --continue before we attach.
        let attachWithRestart =
            "tmux list-panes -t " + escaped + " -F '#{pane_current_command}' | grep -q claude || " +
            "tmux send-keys -t " + escaped + " " + escapedCmd + " Enter; " +
            attachCommand(sessionName: sessionName)

        let tmuxBranch =
            "tmux has-session -t " + escaped + " 2>/dev/null && { " +
            attachWithRestart + "; } || " +
            newSessionCommand(sessionName: sessionName, directory: directory, initialCommand: initialCommand)

        let directFallback =
            "cd " + shellEscape(directory) + " && exec " + escapedCmd

        // If tmux is not installed fall back to a plain cd + exec
        return "(command -v tmux >/dev/null 2>&1 && (" + tmuxBranch + ")) || (" + directFallback + ")"
    }

    private func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
