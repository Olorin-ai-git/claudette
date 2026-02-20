import Foundation
import Security
import os

enum KeychainError: LocalizedError {
    case encodingFailed
    case storeFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode data for Keychain storage"
        case .storeFailed(let status):
            return "Keychain store failed with status: \(status)"
        case .deleteFailed(let status):
            return "Keychain delete failed with status: \(status)"
        }
    }
}

protocol KeychainServiceProtocol: Sendable {
    func storePassword(_ password: String, account: String) throws
    func retrievePassword(account: String) -> String?
    func deletePassword(account: String) throws
    func storeConnectionSettings(_ settings: ConnectionSettings) throws
    func retrieveConnectionSettings() -> ConnectionSettings?
    func deleteConnectionSettings() throws
}

final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let serviceName: String
    private let logger: Logger
    private static let settingsAccount = "connection_settings"

    init(serviceName: String, logger: Logger) {
        self.serviceName = serviceName
        self.logger = logger
    }

    func storePassword(_ password: String, account: String) throws {
        try? deletePassword(account: account)

        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain store failed for account \(account, privacy: .public): status \(status)")
            throw KeychainError.storeFailed(status: status)
        }

        logger.info("Stored credential for account: \(account, privacy: .public)")
    }

    func retrievePassword(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }

    func deletePassword(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    func storeConnectionSettings(_ settings: ConnectionSettings) throws {
        try? deleteConnectionSettings()

        let data: Data
        do {
            data = try JSONEncoder().encode(settings)
        } catch {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: Self.settingsAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Failed to store connection settings: status \(status)")
            throw KeychainError.storeFailed(status: status)
        }

        logger.info("Stored connection settings for \(settings.host, privacy: .public)")
    }

    func retrieveConnectionSettings() -> ConnectionSettings? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: Self.settingsAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let settings = try? JSONDecoder().decode(ConnectionSettings.self, from: data) else {
            return nil
        }

        return settings
    }

    func deleteConnectionSettings() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: Self.settingsAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}
