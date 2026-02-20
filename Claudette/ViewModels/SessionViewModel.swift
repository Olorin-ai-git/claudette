import Foundation
import os

@MainActor
final class SessionViewModel: ObservableObject {
    let connectionManager: SSHConnectionManager
    let settings: ConnectionSettings

    private let keychainService: KeychainServiceProtocol
    private let logger: Logger

    init(
        settings: ConnectionSettings,
        connectionManager: SSHConnectionManager,
        keychainService: KeychainServiceProtocol,
        logger: Logger
    ) {
        self.settings = settings
        self.connectionManager = connectionManager
        self.keychainService = keychainService
        self.logger = logger
    }

    func connect() {
        let credential: String
        switch settings.authMethod {
        case .password:
            let account = settings.username + "@" + settings.host
            credential = keychainService.retrievePassword(account: account) ?? ""
        case .privateKey(let keyTag):
            credential = keychainService.retrievePassword(account: keyTag) ?? ""
        }

        logger.info("Initiating connection to \(self.settings.host, privacy: .public)")
        connectionManager.connect(settings: settings, credential: credential)
    }

    func disconnect() {
        logger.info("User requested disconnect from \(self.settings.host, privacy: .public)")
        connectionManager.disconnect()
    }
}
