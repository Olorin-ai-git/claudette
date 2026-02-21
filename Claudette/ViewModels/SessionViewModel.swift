import Citadel
import CryptoKit
import Foundation
import NIOSSH
import os

struct HostKeyAlertState: Identifiable, Equatable {
    let id = UUID()
    let result: HostKeyVerificationResult
    let fingerprint: String
    let hostIdentifier: String
    let continuation: CheckedContinuation<Bool, Never>

    static func == (lhs: HostKeyAlertState, rhs: HostKeyAlertState) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class SessionViewModel: ObservableObject, HostKeyVerificationDelegate {
    let connectionManager: SSHConnectionManager
    let settings: ConnectionSettings
    let profile: ServerProfile
    let agentParser: AgentActivityParser
    let permissionService: PermissionNotificationService

    @Published var hostKeyAlert: HostKeyAlertState?
    @Published private(set) var claudeResources: [ClaudeResource] = []
    @Published private(set) var isDiscoveringResources: Bool = false

    private let keychainService: KeychainServiceProtocol
    private let hostKeyStore: HostKeyStoreProtocol
    private let hostKeyValidator: TOFUHostKeyValidator
    private let logger: Logger
    private var hasDiscoveredResources = false

    var keychainServiceRef: KeychainServiceProtocol {
        keychainService
    }

    var hostKeyStoreRef: HostKeyStoreProtocol {
        hostKeyStore
    }

    init(
        settings: ConnectionSettings,
        profile: ServerProfile,
        connectionManager: SSHConnectionManager,
        keychainService: KeychainServiceProtocol,
        hostKeyStore: HostKeyStoreProtocol,
        hostKeyValidator: TOFUHostKeyValidator,
        logger: Logger
    ) {
        self.settings = settings
        self.profile = profile
        self.connectionManager = connectionManager
        self.keychainService = keychainService
        self.hostKeyStore = hostKeyStore
        self.hostKeyValidator = hostKeyValidator
        self.logger = logger

        let parser = AgentActivityParser(
            logger: LoggerFactory.logger(category: "AgentParser")
        )
        agentParser = parser

        let notifications = PermissionNotificationService(
            logger: LoggerFactory.logger(category: "PermissionNotification")
        )
        permissionService = notifications

        connectionManager.outputInterceptor = { [weak parser, weak notifications] bytes in
            Task { @MainActor in
                parser?.processOutput(bytes)
                notifications?.processOutput(bytes)
            }
        }

        hostKeyValidator.delegate = self
    }

    func connect() {
        Task { await permissionService.requestAuthorization() }
        agentParser.reset()

        let credential: String
        switch settings.authMethod {
        case .password:
            credential = keychainService.retrievePassword(profileId: profile.id) ?? ""
        case .generatedKey, .importedKey:
            credential = ""
        }

        let validator = hostKeyValidator.makeValidator(host: settings.host, port: settings.port)

        let hostForLog = settings.host
        logger.info("Initiating connection to \(hostForLog, privacy: .public)")
        connectionManager.connect(
            settings: settings,
            credential: credential,
            hostKeyValidator: validator,
            profileId: profile.id
        )
    }

    func reconnect() {
        let host = settings.host
        logger.info("Attempting reconnect to \(host, privacy: .public)")
        connectionManager.reconnect()
    }

    func disconnect() {
        let hostForLog = settings.host
        logger.info("User requested disconnect from \(hostForLog, privacy: .public)")
        connectionManager.disconnect()
    }

    func sendSnippet(_ command: String) {
        let textBytes = Array((command + " ").utf8)
        connectionManager.sendToRemote(textBytes[...])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            let enter: [UInt8] = [0x0D]
            self?.connectionManager.sendToRemote(enter[...])
        }
    }

    // MARK: - Resource Discovery

    func discoverResourcesIfNeeded() {
        guard !hasDiscoveredResources, !isDiscoveringResources else { return }
        Task { await discoverResources() }
    }

    func refreshResources() {
        hasDiscoveredResources = false
        Task { await discoverResources() }
    }

    private func discoverResources() async {
        isDiscoveringResources = true

        let fileBrowserService = RemoteFileBrowserService(
            logger: LoggerFactory.logger(category: "ResourceBrowser")
        )
        let discoveryService = ClaudeResourceDiscoveryService(
            fileBrowserService: fileBrowserService,
            logger: LoggerFactory.logger(category: "ResourceDiscovery")
        )

        do {
            let authMethod: SSHAuthenticationMethod
            switch profile.authMethod {
            case .password:
                let password = keychainService.retrievePassword(profileId: profile.id) ?? ""
                authMethod = .passwordBased(username: profile.username, password: password)
            case let .generatedKey(keyTag), let .importedKey(keyTag):
                guard let keyData = keychainService.retrievePrivateKeyData(keyTag: keyTag) else {
                    isDiscoveringResources = false
                    return
                }
                let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
                authMethod = .ed25519(username: profile.username, privateKey: privateKey)
            }

            let validator = TOFUHostKeyValidator(
                hostKeyStore: hostKeyStore,
                logger: LoggerFactory.logger(category: "HostKeyValidator")
            )

            try await fileBrowserService.connect(
                host: settings.host,
                port: settings.port,
                username: settings.username,
                authMethod: authMethod,
                hostKeyValidator: validator.makeValidator(host: settings.host, port: settings.port)
            )

            await discoveryService.discover(
                projectPath: settings.projectPath,
                username: settings.username
            )

            claudeResources = discoveryService.resources
            hasDiscoveredResources = true
        } catch {
            logger.error("Resource discovery failed: \(error.localizedDescription)")
        }

        fileBrowserService.disconnect()
        isDiscoveringResources = false
    }

    // MARK: - HostKeyVerificationDelegate

    nonisolated func verifyHostKey(
        result: HostKeyVerificationResult,
        fingerprint: String,
        hostIdentifier: String
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.hostKeyAlert = HostKeyAlertState(
                    result: result,
                    fingerprint: fingerprint,
                    hostIdentifier: hostIdentifier,
                    continuation: continuation
                )
            }
        }
    }

    func acceptHostKey() {
        guard let alert = hostKeyAlert else { return }
        hostKeyAlert = nil
        alert.continuation.resume(returning: true)
    }

    func rejectHostKey() {
        guard let alert = hostKeyAlert else { return }
        hostKeyAlert = nil
        alert.continuation.resume(returning: false)
    }
}
