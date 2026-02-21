import Citadel
import Combine
import CryptoKit
import Foundation
import NIOSSH
import os
import UIKit

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
    let authInterceptor: AuthURLInterceptor

    // Tab Management
    @Published private(set) var tabs: [TerminalTab] = []
    @Published var activeTabId: UUID = .init()
    @Published private(set) var activeConnectionState: ConnectionState = .disconnected
    private var activeStateCancellable: AnyCancellable?
    private var tabCounter: Int = 1

    @Published var hostKeyAlert: HostKeyAlertState?
    @Published private(set) var claudeResources: [ClaudeResource] = []
    @Published private(set) var isDiscoveringResources: Bool = false

    private let config: AppConfiguration
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

    var activeConnectionManager: SSHConnectionManager {
        tabs.first(where: { $0.id == activeTabId })?.connectionManager ?? connectionManager
    }

    init(
        settings: ConnectionSettings,
        profile: ServerProfile,
        connectionManager: SSHConnectionManager,
        config: AppConfiguration,
        keychainService: KeychainServiceProtocol,
        hostKeyStore: HostKeyStoreProtocol,
        hostKeyValidator: TOFUHostKeyValidator,
        logger: Logger
    ) {
        self.settings = settings
        self.profile = profile
        self.connectionManager = connectionManager
        self.config = config
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

        let auth = AuthURLInterceptor(
            logger: LoggerFactory.logger(category: "AuthURL")
        )
        authInterceptor = auth

        connectionManager.outputInterceptor = { [weak parser, weak notifications, weak auth] bytes in
            Task { @MainActor in
                parser?.processOutput(bytes)
                notifications?.processOutput(bytes)
                auth?.processOutput(bytes)
            }
        }

        hostKeyValidator.delegate = self

        let firstTab = TerminalTab(connectionManager: connectionManager, label: "Terminal 1")
        tabs = [firstTab]
        activeTabId = firstTab.id
        observeActiveTab()
    }

    // MARK: - Tab Management

    func addTab() {
        tabCounter += 1
        let newManager = SSHConnectionManager(
            config: config,
            keychainService: keychainService,
            logger: LoggerFactory.logger(category: "SSHConnection-\(tabCounter)")
        )
        wireInterceptor(on: newManager)

        let tab = TerminalTab(connectionManager: newManager, label: "Terminal \(tabCounter)")
        tabs.append(tab)
        activeTabId = tab.id
        observeActiveTab()
        connectTab(tab)
    }

    func closeTab(id: UUID) {
        guard tabs.count > 1 else { return }
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }

        tabs[index].connectionManager.disconnect()
        tabs.remove(at: index)

        if activeTabId == id {
            let newIndex = min(index, tabs.count - 1)
            activeTabId = tabs[newIndex].id
        }

        observeActiveTab()
    }

    func selectTab(id: UUID) {
        guard id != activeTabId else { return }
        activeTabId = id
        observeActiveTab()
    }

    private func connectTab(_ tab: TerminalTab) {
        let credential: String
        switch settings.authMethod {
        case .password:
            credential = keychainService.retrievePassword(profileId: profile.id) ?? ""
        case .generatedKey, .importedKey:
            credential = ""
        }

        let validator = hostKeyValidator.makeValidator(host: settings.host, port: settings.port)

        tab.connectionManager.connect(
            settings: settings,
            credential: credential,
            hostKeyValidator: validator,
            profileId: tab.id
        )
    }

    private func wireInterceptor(on manager: SSHConnectionManager) {
        let parser = agentParser
        let notifications = permissionService
        let auth = authInterceptor
        manager.outputInterceptor = { [weak parser, weak notifications, weak auth] bytes in
            Task { @MainActor in
                parser?.processOutput(bytes)
                notifications?.processOutput(bytes)
                auth?.processOutput(bytes)
            }
        }
    }

    private func observeActiveTab() {
        activeStateCancellable?.cancel()
        guard let tab = tabs.first(where: { $0.id == activeTabId }) else { return }
        activeConnectionState = tab.connectionManager.connectionState
        activeStateCancellable = tab.connectionManager.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.activeConnectionState = state
            }
    }

    // MARK: - Connection Lifecycle

    func connect() {
        Task { await permissionService.requestAuthorization() }
        agentParser.reset()

        guard let firstTab = tabs.first else { return }

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
        firstTab.connectionManager.connect(
            settings: settings,
            credential: credential,
            hostKeyValidator: validator,
            profileId: profile.id
        )
    }

    func reconnect() {
        let host = settings.host
        logger.info("Attempting reconnect to \(host, privacy: .public)")
        for tab in tabs {
            switch tab.connectionManager.connectionState {
            case .disconnected, .failed:
                tab.connectionManager.reconnect()
            default:
                break
            }
        }
    }

    func disconnect() {
        let hostForLog = settings.host
        logger.info("User requested disconnect from \(hostForLog, privacy: .public)")
        for tab in tabs {
            tab.connectionManager.disconnect()
        }
    }

    func sendSnippet(_ command: String) {
        let textBytes = Array((command + " ").utf8)
        activeConnectionManager.sendToRemote(textBytes[...])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            let enter: [UInt8] = [0x0D]
            self?.activeConnectionManager.sendToRemote(enter[...])
        }
    }

    /// Copies the active terminal's output buffer to the iPhone clipboard.
    func copySessionToClipboard() -> Bool {
        let content = activeConnectionManager.getTerminalContent()
        guard !content.isEmpty else { return false }
        UIPasteboard.general.string = content
        logger.info("Session buffer copied to clipboard")
        return true
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
