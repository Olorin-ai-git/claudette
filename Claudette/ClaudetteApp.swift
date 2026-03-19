import os
import SwiftUI

@main
struct ClaudetteApp: App {
    private let config: AppConfiguration
    private let keychainService: KeychainServiceProtocol
    private let profileStore: ProfileStoreProtocol
    private let hostKeyStore: HostKeyStoreProtocol
    private let sshKeyService: SSHKeyServiceProtocol
    @StateObject private var connectionManager: SSHConnectionManager
    @StateObject private var bonjourService: BonjourDiscoveryService
    @StateObject private var appIconManager = AppIconManager()
    @State private var showingSplash = true

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

        let profileStore = ProfileStore(
            logger: LoggerFactory.logger(category: "ProfileStore")
        )
        self.profileStore = profileStore

        let hostKeyStore = HostKeyStore(
            logger: LoggerFactory.logger(category: "HostKeyStore")
        )
        self.hostKeyStore = hostKeyStore

        let sshKeyService = SSHKeyService(
            keychainService: keychainService,
            logger: LoggerFactory.logger(category: "SSHKeyService")
        )
        self.sshKeyService = sshKeyService

        let connectionManager = SSHConnectionManager(
            config: config,
            keychainService: keychainService,
            logger: LoggerFactory.logger(category: "SSHConnection")
        )
        _connectionManager = StateObject(wrappedValue: connectionManager)

        _bonjourService = StateObject(wrappedValue: BonjourDiscoveryService(
            serviceType: config.bonjourServiceType,
            domain: config.bonjourDomain,
            logger: LoggerFactory.logger(category: "Bonjour")
        ))

        // Migrate legacy connection settings if present
        Self.migrateLegacySettings(
            keychainService: keychainService,
            profileStore: profileStore,
            logger: logger
        )
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(
                    config: config,
                    keychainService: keychainService,
                    profileStore: profileStore,
                    hostKeyStore: hostKeyStore,
                    sshKeyService: sshKeyService,
                    connectionManager: connectionManager,
                    bonjourService: bonjourService,
                    appIconManager: appIconManager
                )

                if showingSplash {
                    SplashView(config: config) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showingSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private static func migrateLegacySettings(
        keychainService: KeychainService,
        profileStore: ProfileStore,
        logger: Logger
    ) {
        guard let legacy = keychainService.retrieveLegacyConnectionSettings() else {
            return
        }

        logger.info("Found legacy connection settings, migrating...")

        let legacyAccount = legacy.username + "@" + legacy.host
        let legacyPassword = keychainService.retrieveLegacyPassword(account: legacyAccount)

        let profile = ServerProfile(
            name: legacy.host,
            host: legacy.host,
            port: legacy.port,
            username: legacy.username,
            authMethod: .password,
            lastProjectPath: legacy.projectFolder
        )

        do {
            try profileStore.saveProfile(profile)

            if let password = legacyPassword {
                try keychainService.storePassword(password, profileId: profile.id)
            }

            // Clean up legacy data
            try? keychainService.deleteLegacyConnectionSettings()
            if legacyPassword != nil {
                try? keychainService.deleteLegacyPassword(account: legacyAccount)
            }

            logger.info("Successfully migrated legacy settings to profile: \(profile.name, privacy: .public)")
        } catch {
            logger.error("Failed to migrate legacy settings: \(error.localizedDescription)")
        }
    }
}
