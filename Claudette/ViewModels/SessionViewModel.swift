import Foundation
import os

struct HostKeyAlertState: Identifiable {
    let id = UUID()
    let result: HostKeyVerificationResult
    let fingerprint: String
    let hostIdentifier: String
    let continuation: CheckedContinuation<Bool, Never>
}

@MainActor
final class SessionViewModel: ObservableObject, HostKeyVerificationDelegate {
    let connectionManager: SSHConnectionManager
    let settings: ConnectionSettings
    let profile: ServerProfile

    @Published var hostKeyAlert: HostKeyAlertState?

    private let keychainService: KeychainServiceProtocol
    private let hostKeyValidator: TOFUHostKeyValidator
    private let logger: Logger

    init(
        settings: ConnectionSettings,
        profile: ServerProfile,
        connectionManager: SSHConnectionManager,
        keychainService: KeychainServiceProtocol,
        hostKeyValidator: TOFUHostKeyValidator,
        logger: Logger
    ) {
        self.settings = settings
        self.profile = profile
        self.connectionManager = connectionManager
        self.keychainService = keychainService
        self.hostKeyValidator = hostKeyValidator
        self.logger = logger

        hostKeyValidator.delegate = self
    }

    func connect() {
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
            hostKeyValidator: validator
        )
    }

    func disconnect() {
        let hostForLog = settings.host
        logger.info("User requested disconnect from \(hostForLog, privacy: .public)")
        connectionManager.disconnect()
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
