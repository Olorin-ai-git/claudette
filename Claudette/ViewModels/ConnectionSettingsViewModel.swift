import Foundation
import os

@MainActor
final class ConnectionSettingsViewModel: ObservableObject {
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var authMethod: AuthMethod = .password
    @Published var selectedProject: String = ""
    @Published var availableProjects: [String] = []
    @Published var validationError: String?

    private let keychainService: KeychainServiceProtocol
    private let config: AppConfiguration
    private let logger: Logger

    init(keychainService: KeychainServiceProtocol, config: AppConfiguration, logger: Logger) {
        self.keychainService = keychainService
        self.config = config
        self.logger = logger

        availableProjects = config.sshProjectFolders

        let defaultProject = "olorin/olorin-media/bayit-plus"

        if let saved = keychainService.retrieveConnectionSettings() {
            host = saved.host
            port = String(saved.port)
            username = saved.username
            authMethod = saved.authMethod
            selectedProject = availableProjects.contains(saved.projectFolder) ? saved.projectFolder : defaultProject
            let account = saved.username + "@" + saved.host
            password = keychainService.retrievePassword(account: account) ?? ""
        } else {
            host = config.sshDefaultHost
            port = String(config.sshDefaultPort)
            username = config.sshDefaultUsername
            selectedProject = defaultProject
        }
    }

    func validate() -> Bool {
        validationError = nil

        guard !host.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Hostname is required"
            return false
        }

        guard let portNum = Int(port), portNum > 0, portNum <= 65535 else {
            validationError = "Port must be between 1 and 65535"
            return false
        }

        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Username is required"
            return false
        }

        if case .password = authMethod {
            guard !password.isEmpty else {
                validationError = "Password is required"
                return false
            }
        }

        guard !selectedProject.isEmpty else {
            validationError = "Select a project folder"
            return false
        }

        return true
    }

    func saveAndConnect() -> ConnectionSettings? {
        guard validate() else { return nil }
        guard let portNum = Int(port) else { return nil }

        let settings = ConnectionSettings(
            host: host.trimmingCharacters(in: .whitespaces),
            port: portNum,
            username: username.trimmingCharacters(in: .whitespaces),
            authMethod: authMethod,
            projectFolder: selectedProject
        )

        do {
            try keychainService.storeConnectionSettings(settings)

            let account = settings.username + "@" + settings.host
            if case .password = settings.authMethod {
                try keychainService.storePassword(password, account: account)
            }

            logger.info("Saved connection settings for \(settings.host, privacy: .public)")
            return settings
        } catch {
            logger.error("Failed to save settings: \(error.localizedDescription)")
            validationError = "Failed to save credentials: \(error.localizedDescription)"
            return nil
        }
    }
}
