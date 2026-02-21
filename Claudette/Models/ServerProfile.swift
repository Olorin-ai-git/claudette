import Foundation

struct ServerProfile: Codable, Sendable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var lastProjectPath: String?
    var macAddress: String?
    let createdAt: Date
    var lastConnectedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int,
        username: String,
        authMethod: AuthMethod,
        lastProjectPath: String? = nil,
        macAddress: String? = nil,
        createdAt: Date = Date(),
        lastConnectedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.lastProjectPath = lastProjectPath
        self.macAddress = macAddress
        self.createdAt = createdAt
        self.lastConnectedAt = lastConnectedAt
    }

    func toConnectionSettings(projectPath: String) -> ConnectionSettings {
        ConnectionSettings(
            host: host,
            port: port,
            username: username,
            authMethod: authMethod,
            projectPath: projectPath
        )
    }
}
