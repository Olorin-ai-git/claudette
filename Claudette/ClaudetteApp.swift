import SwiftUI
import os

@main
struct ClaudetteApp: App {
    private let config: AppConfiguration
    private let keychainService: KeychainServiceProtocol
    @StateObject private var connectionManager: SSHConnectionManager
    @StateObject private var connectionSettingsViewModel: ConnectionSettingsViewModel

    init() {
        let config = AppConfiguration()
        LoggerFactory.configure(subsystem: config.loggerSubsystem)

        let logger = LoggerFactory.logger(category: "AppLifecycle")
        logger.info("Application launched")

        self.config = config

        let keychainService = KeychainService(
            serviceName: config.keychainServiceName,
            logger: LoggerFactory.logger(category: "Keychain")
        )
        self.keychainService = keychainService

        let connectionManager = SSHConnectionManager(
            config: config,
            logger: LoggerFactory.logger(category: "SSHConnection")
        )
        _connectionManager = StateObject(wrappedValue: connectionManager)

        _connectionSettingsViewModel = StateObject(wrappedValue: ConnectionSettingsViewModel(
            keychainService: keychainService,
            config: config,
            logger: LoggerFactory.logger(category: "ConnectionSettings")
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                config: config,
                keychainService: keychainService,
                connectionManager: connectionManager,
                connectionSettingsViewModel: connectionSettingsViewModel
            )
        }
    }
}
