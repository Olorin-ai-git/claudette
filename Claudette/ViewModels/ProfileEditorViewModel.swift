import Citadel
import Combine
import Foundation
import NIOSSH
import os

@MainActor
final class ProfileEditorViewModel: ObservableObject {
    @Published var profileName: String = ""
    @Published var host: String = ""
    @Published var port: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var authMethodSelection: AuthMethodSelection = .password
    @Published var validationError: String?

    @Published var publicKeyString: String?
    @Published var showImportKeySheet: Bool = false
    @Published var bonjourHosts: [BonjourHost] = []

    private let profileStore: ProfileStoreProtocol
    private let keychainService: KeychainServiceProtocol
    private let sshKeyService: SSHKeyServiceProtocol
    private let bonjourService: BonjourDiscoveryService
    private let config: AppConfiguration
    private let logger: Logger

    private var existingProfile: ServerProfile?
    private var generatedKeyTag: String?
    private var importedKeyTag: String?
    private var cancellables = Set<AnyCancellable>()

    enum AuthMethodSelection: String, CaseIterable {
        case password = "Password"
        case sshKey = "SSH Key"
    }

    init(
        profile: ServerProfile? = nil,
        profileStore: ProfileStoreProtocol,
        keychainService: KeychainServiceProtocol,
        sshKeyService: SSHKeyServiceProtocol,
        bonjourService: BonjourDiscoveryService,
        config: AppConfiguration,
        logger: Logger
    ) {
        existingProfile = profile
        self.profileStore = profileStore
        self.keychainService = keychainService
        self.sshKeyService = sshKeyService
        self.bonjourService = bonjourService
        self.config = config
        self.logger = logger

        if let profile {
            profileName = profile.name
            host = profile.host
            port = String(profile.port)
            username = profile.username

            switch profile.authMethod {
            case .password:
                authMethodSelection = .password
                password = keychainService.retrievePassword(profileId: profile.id) ?? ""
            case let .generatedKey(keyTag):
                authMethodSelection = .sshKey
                generatedKeyTag = keyTag
                publicKeyString = sshKeyService.publicKeyString(forKeyTag: keyTag)
            case let .importedKey(keyTag):
                authMethodSelection = .sshKey
                importedKeyTag = keyTag
                publicKeyString = sshKeyService.publicKeyString(forKeyTag: keyTag)
            }
        } else {
            port = String(config.sshDefaultPort)
        }

        bonjourService.$discoveredHosts
            .receive(on: RunLoop.main)
            .assign(to: &$bonjourHosts)
    }

    func startBonjourDiscovery() {
        bonjourService.startDiscovery()
    }

    func stopBonjourDiscovery() {
        bonjourService.stopDiscovery()
    }

    func selectBonjourHost(_ bonjourHost: BonjourHost) {
        host = bonjourHost.hostname
        port = String(bonjourHost.port)
        if profileName.isEmpty {
            profileName = bonjourHost.displayName
        }
        logger.info("Selected Bonjour host: \(bonjourHost.hostname, privacy: .public)")
    }

    func generateSSHKey() {
        do {
            let result = try sshKeyService.generateEd25519KeyPair()
            generatedKeyTag = result.privateKeyTag
            importedKeyTag = nil
            publicKeyString = result.publicKeyString
            logger.info("Generated new SSH key pair")
        } catch {
            logger.error("SSH key generation failed: \(error.localizedDescription)")
            validationError = "Key generation failed: " + error.localizedDescription
        }
    }

    func importSSHKey(_ pemString: String) {
        do {
            let result = try sshKeyService.importPrivateKey(pemString: pemString)
            importedKeyTag = result.privateKeyTag
            generatedKeyTag = nil
            publicKeyString = result.publicKeyString
            showImportKeySheet = false
            logger.info("Imported SSH key")
        } catch {
            logger.error("SSH key import failed: \(error.localizedDescription)")
            validationError = "Key import failed: " + error.localizedDescription
        }
    }

    func validate() -> Bool {
        validationError = nil

        guard !profileName.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = "Profile name is required"
            return false
        }

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

        if authMethodSelection == .password {
            guard !password.isEmpty else {
                validationError = "Password is required"
                return false
            }
        }

        if authMethodSelection == .sshKey {
            guard generatedKeyTag != nil || importedKeyTag != nil else {
                validationError = "Generate or import an SSH key first"
                return false
            }
        }

        return true
    }

    func save() -> ServerProfile? {
        guard validate() else { return nil }
        guard let portNum = Int(port) else { return nil }

        let authMethod: AuthMethod
        switch authMethodSelection {
        case .password:
            authMethod = .password
        case .sshKey:
            if let tag = generatedKeyTag {
                authMethod = .generatedKey(keyTag: tag)
            } else if let tag = importedKeyTag {
                authMethod = .importedKey(keyTag: tag)
            } else {
                validationError = "No SSH key available"
                return nil
            }
        }

        let profile: ServerProfile
        if var existing = existingProfile {
            existing.name = profileName.trimmingCharacters(in: .whitespaces)
            existing.host = host.trimmingCharacters(in: .whitespaces)
            existing.port = portNum
            existing.username = username.trimmingCharacters(in: .whitespaces)
            existing.authMethod = authMethod
            profile = existing
        } else {
            profile = ServerProfile(
                name: profileName.trimmingCharacters(in: .whitespaces),
                host: host.trimmingCharacters(in: .whitespaces),
                port: portNum,
                username: username.trimmingCharacters(in: .whitespaces),
                authMethod: authMethod
            )
        }

        do {
            try profileStore.saveProfile(profile)

            if case .password = authMethod {
                try keychainService.storePassword(password, profileId: profile.id)
            }

            logger.info("Saved profile: \(profile.name, privacy: .public)")
            return profile
        } catch {
            logger.error("Failed to save profile: \(error.localizedDescription)")
            validationError = "Failed to save: " + error.localizedDescription
            return nil
        }
    }
}
