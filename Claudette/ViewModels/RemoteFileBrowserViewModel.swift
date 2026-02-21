import Citadel
import CryptoKit
import Foundation
import NIOSSH
import os

@MainActor
final class RemoteFileBrowserViewModel: ObservableObject {
    @Published var currentPath: String = ""
    @Published var entries: [RemoteFileEntry] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    var pathComponents: [String] {
        guard !currentPath.isEmpty else { return [] }
        var components = currentPath.components(separatedBy: "/").filter { !$0.isEmpty }
        components.insert("/", at: 0)
        return components
    }

    let fileBrowserServiceRef: RemoteFileBrowserService
    private var fileBrowserService: RemoteFileBrowserService {
        fileBrowserServiceRef
    }

    private let profile: ServerProfile
    private let keychainService: KeychainServiceProtocol
    private let hostKeyValidator: TOFUHostKeyValidator
    private let logger: Logger

    init(
        profile: ServerProfile,
        fileBrowserService: RemoteFileBrowserService,
        keychainService: KeychainServiceProtocol,
        hostKeyValidator: TOFUHostKeyValidator,
        logger: Logger
    ) {
        self.profile = profile
        fileBrowserServiceRef = fileBrowserService
        self.keychainService = keychainService
        self.hostKeyValidator = hostKeyValidator
        self.logger = logger
    }

    func loadInitialDirectory() async {
        isLoading = true
        error = nil

        do {
            if !fileBrowserService.isConnected {
                let authMethod = try buildAuthMethod()

                let validator = hostKeyValidator.makeValidator(host: profile.host, port: profile.port)

                try await fileBrowserService.connect(
                    host: profile.host,
                    port: profile.port,
                    username: profile.username,
                    authMethod: authMethod,
                    hostKeyValidator: validator
                )
            }

            let startPath: String
            if let lastPath = profile.lastProjectPath, !lastPath.isEmpty {
                startPath = lastPath
            } else {
                startPath = try await fileBrowserService.getHomeDirectory(username: profile.username)
            }

            currentPath = startPath
            let loadedEntries = try await fileBrowserService.listDirectory(atPath: startPath)
            entries = loadedEntries
            isLoading = false

            logger.info("Loaded directory: \(startPath, privacy: .public) with \(loadedEntries.count) entries")

        } catch {
            self.error = error.localizedDescription
            isLoading = false
            logger.error("Failed to load directory: \(error.localizedDescription)")
        }
    }

    func navigateTo(_ entry: RemoteFileEntry) async {
        guard entry.isDirectory else { return }

        isLoading = true
        error = nil

        do {
            currentPath = entry.path
            entries = try await fileBrowserService.listDirectory(atPath: entry.path)
            isLoading = false
            logger.info("Navigated to: \(entry.path, privacy: .public)")
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            logger.error("Failed to navigate: \(error.localizedDescription)")
        }
    }

    func navigateUp() async {
        let parentPath: String
        if let lastSlash = currentPath.lastIndex(of: "/"), lastSlash != currentPath.startIndex {
            parentPath = String(currentPath[currentPath.startIndex ..< lastSlash])
        } else {
            parentPath = "/"
        }

        isLoading = true
        error = nil

        do {
            currentPath = parentPath
            entries = try await fileBrowserService.listDirectory(atPath: parentPath)
            isLoading = false
            logger.info("Navigated up to: \(parentPath, privacy: .public)")
        } catch {
            self.error = error.localizedDescription
            isLoading = false
            logger.error("Failed to navigate up: \(error.localizedDescription)")
        }
    }

    func navigateToPathComponent(index: Int) async {
        guard index < pathComponents.count else { return }

        let targetPath: String
        if index == 0 {
            targetPath = "/"
        } else {
            let components = Array(pathComponents[1 ... index])
            targetPath = "/" + components.joined(separator: "/")
        }

        isLoading = true
        error = nil

        do {
            currentPath = targetPath
            entries = try await fileBrowserService.listDirectory(atPath: targetPath)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func selectCurrentDirectory() -> String {
        fileBrowserService.disconnect()
        return currentPath
    }

    func disconnect() {
        fileBrowserService.disconnect()
    }

    private func buildAuthMethod() throws -> SSHAuthenticationMethod {
        switch profile.authMethod {
        case .password:
            let password = keychainService.retrievePassword(profileId: profile.id) ?? ""
            return .passwordBased(username: profile.username, password: password)

        case let .generatedKey(keyTag), let .importedKey(keyTag):
            guard let keyData = keychainService.retrievePrivateKeyData(keyTag: keyTag) else {
                throw SSHKeyAuthError.keyNotFound
            }
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
            return .ed25519(username: profile.username, privateKey: privateKey)
        }
    }
}
