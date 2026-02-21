import Foundation

struct TerminalTab: Identifiable {
    let id: UUID
    let connectionManager: SSHConnectionManager
    let label: String

    init(connectionManager: SSHConnectionManager, label: String) {
        id = UUID()
        self.connectionManager = connectionManager
        self.label = label
    }
}
