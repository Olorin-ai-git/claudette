import Foundation
import os
import Security

enum KeychainError: LocalizedError {
    case encodingFailed
    case storeFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode data for Keychain storage"
        case let .storeFailed(status):
            return "Keychain store failed with status: \(status)"
        case let .deleteFailed(status):
            return "Keychain delete failed with status: \(status)"
        }
    }
}

protocol KeychainServiceProtocol: Sendable {
    func storePassword(_ password: String, profileId: UUID) throws
    func retrievePassword(profileId: UUID) -> String?
    func deletePassword(profileId: UUID) throws
    func storePrivateKeyData(_ data: Data, keyTag: String) throws
    func retrievePrivateKeyData(keyTag: String) -> Data?
    func deletePrivateKeyData(keyTag: String) throws
    func retrieveLegacyConnectionSettings() -> LegacyConnectionSettings?
    func deleteLegacyConnectionSettings() throws
    func retrieveLegacyPassword(account: String) -> String?
    func deleteLegacyPassword(account: String) throws
}

struct LegacyConnectionSettings: Codable {
    var host: String
    var port: Int
    var username: String
    var projectFolder: String
}

final class KeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let serviceName: String
    private let logger: Logger
    private static let legacySettingsAccount = "connection_settings"

    init(serviceName: String, logger: Logger) {
        self.serviceName = serviceName
        self.logger = logger
    }

    // MARK: - Profile Passwords

    func storePassword(_ password: String, profileId: UUID) throws {
        let account = "profile_" + profileId.uuidString
        try storeGenericPassword(password, account: account)
    }

    func retrievePassword(profileId: UUID) -> String? {
        let account = "profile_" + profileId.uuidString
        return retrieveGenericPassword(account: account)
    }

    func deletePassword(profileId: UUID) throws {
        let account = "profile_" + profileId.uuidString
        try deleteGenericItem(account: account)
    }

    // MARK: - Private Key Storage

    func storePrivateKeyData(_ data: Data, keyTag: String) throws {
        try? deletePrivateKeyData(keyTag: keyTag)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "key_" + keyTag,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Failed to store private key data: status \(status)")
            throw KeychainError.storeFailed(status: status)
        }

        logger.info("Stored private key with tag: \(keyTag, privacy: .public)")
    }

    func retrievePrivateKeyData(keyTag: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "key_" + keyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return data
    }

    func deletePrivateKeyData(keyTag: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: "key_" + keyTag,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    // MARK: - Legacy Migration

    func retrieveLegacyConnectionSettings() -> LegacyConnectionSettings? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: Self.legacySettingsAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let settings = try? JSONDecoder().decode(LegacyConnectionSettings.self, from: data)
        else {
            return nil
        }

        return settings
    }

    func deleteLegacyConnectionSettings() throws {
        try deleteGenericItem(account: Self.legacySettingsAccount)
    }

    func retrieveLegacyPassword(account: String) -> String? {
        return retrieveGenericPassword(account: account)
    }

    func deleteLegacyPassword(account: String) throws {
        try deleteGenericItem(account: account)
    }

    // MARK: - Generic Helpers

    private func storeGenericPassword(_ password: String, account: String) throws {
        try? deleteGenericItem(account: account)

        guard let data = password.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("Keychain store failed for account \(account, privacy: .public): status \(status)")
            throw KeychainError.storeFailed(status: status)
        }

        logger.info("Stored credential for account: \(account, privacy: .public)")
    }

    private func retrieveGenericPassword(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return password
    }

    private func deleteGenericItem(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}
