import CryptoKit
import Foundation
import os

protocol SSHKeyServiceProtocol: Sendable {
    func generateEd25519KeyPair() throws -> (privateKeyTag: String, publicKeyString: String)
    func importPrivateKey(pemString: String) throws -> (privateKeyTag: String, publicKeyString: String)
    func publicKeyString(forKeyTag keyTag: String) -> String?
    func deleteKey(keyTag: String) throws
}

enum SSHKeyError: LocalizedError {
    case keyGenerationFailed
    case invalidPEMFormat
    case unsupportedKeyType
    case keychainStoreFailed

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed:
            return "Failed to generate SSH key pair"
        case .invalidPEMFormat:
            return "Invalid PEM format"
        case .unsupportedKeyType:
            return "Unsupported key type — only Ed25519 is supported for generation"
        case .keychainStoreFailed:
            return "Failed to store key in Keychain"
        }
    }
}

final class SSHKeyService: SSHKeyServiceProtocol, @unchecked Sendable {
    private let keychainService: KeychainServiceProtocol
    private let logger: Logger

    init(keychainService: KeychainServiceProtocol, logger: Logger) {
        self.keychainService = keychainService
        self.logger = logger
    }

    func generateEd25519KeyPair() throws -> (privateKeyTag: String, publicKeyString: String) {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey

        let keyTag = UUID().uuidString

        let rawPrivateKeyData = privateKey.rawRepresentation
        do {
            try keychainService.storePrivateKeyData(rawPrivateKeyData, keyTag: keyTag)
        } catch {
            logger.error("Failed to store generated Ed25519 key: \(error.localizedDescription)")
            throw SSHKeyError.keychainStoreFailed
        }

        let publicKeyString = formatEd25519PublicKey(publicKey.rawRepresentation)
        logger.info("Generated Ed25519 key pair with tag: \(keyTag, privacy: .public)")

        return (privateKeyTag: keyTag, publicKeyString: publicKeyString)
    }

    func importPrivateKey(pemString: String) throws -> (privateKeyTag: String, publicKeyString: String) {
        let trimmed = pemString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.contains("PRIVATE KEY") else {
            throw SSHKeyError.invalidPEMFormat
        }

        // Extract base64 content between PEM markers
        let lines = trimmed.components(separatedBy: .newlines)
        let base64Lines = lines.filter { line in
            !line.hasPrefix("-----") && !line.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let base64String = base64Lines.joined()

        guard let derData = Data(base64Encoded: base64String) else {
            throw SSHKeyError.invalidPEMFormat
        }

        // Try Ed25519 first (raw key is 32 bytes, but DER-wrapped is typically 48 bytes)
        if let result = try? importEd25519(derData: derData) {
            return result
        }

        // If the raw data is exactly 32 bytes, try directly as Ed25519
        if derData.count == 32, let result = try? importEd25519Raw(keyData: derData) {
            return result
        }

        throw SSHKeyError.unsupportedKeyType
    }

    func publicKeyString(forKeyTag keyTag: String) -> String? {
        guard let keyData = keychainService.retrievePrivateKeyData(keyTag: keyTag) else {
            return nil
        }

        // Assume Ed25519 (32 bytes raw representation)
        if keyData.count == 32 {
            guard let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData) else {
                return nil
            }
            return formatEd25519PublicKey(privateKey.publicKey.rawRepresentation)
        }

        return nil
    }

    func deleteKey(keyTag: String) throws {
        try keychainService.deletePrivateKeyData(keyTag: keyTag)
        logger.info("Deleted key with tag: \(keyTag, privacy: .public)")
    }

    // MARK: - Ed25519 Helpers

    private func importEd25519(derData: Data) throws -> (privateKeyTag: String, publicKeyString: String) {
        // PKCS#8 Ed25519 private key: 30 2E 02 01 00 30 05 06 03 2B 65 70 04 22 04 20 + 32 bytes
        // The Ed25519 OID is 1.3.101.112 = 06 03 2B 65 70
        let ed25519OID: [UInt8] = [0x06, 0x03, 0x2B, 0x65, 0x70]
        let derBytes = Array(derData)

        guard derBytes.count >= 16 else {
            throw SSHKeyError.invalidPEMFormat
        }

        // Check if this contains the Ed25519 OID
        var oidFound = false
        for i in 0 ..< (derBytes.count - ed25519OID.count) {
            if Array(derBytes[i ..< (i + ed25519OID.count)]) == ed25519OID {
                oidFound = true
                break
            }
        }

        guard oidFound else {
            throw SSHKeyError.unsupportedKeyType
        }

        // The last 32 bytes of the DER should be the raw private key
        // In PKCS#8, the key is wrapped: OCTET STRING { OCTET STRING { 32-byte key } }
        // Find the raw 32-byte key at the end
        let rawKeyData: Data
        if derBytes.count >= 34, derBytes[derBytes.count - 34] == 0x04, derBytes[derBytes.count - 33] == 0x20 {
            rawKeyData = Data(derBytes[(derBytes.count - 32)...])
        } else {
            throw SSHKeyError.invalidPEMFormat
        }

        return try importEd25519Raw(keyData: rawKeyData)
    }

    private func importEd25519Raw(keyData: Data) throws -> (privateKeyTag: String, publicKeyString: String) {
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
        let publicKey = privateKey.publicKey
        let keyTag = UUID().uuidString

        try keychainService.storePrivateKeyData(keyData, keyTag: keyTag)

        let publicKeyString = formatEd25519PublicKey(publicKey.rawRepresentation)
        logger.info("Imported Ed25519 key with tag: \(keyTag, privacy: .public)")

        return (privateKeyTag: keyTag, publicKeyString: publicKeyString)
    }

    private func formatEd25519PublicKey(_ rawPublicKey: Data) -> String {
        // OpenSSH format: "ssh-ed25519 <base64>"
        // The base64 payload is: length-prefixed "ssh-ed25519" + length-prefixed raw public key
        let keyType = "ssh-ed25519"
        let keyTypeData = keyType.data(using: .utf8)!

        var wireFormat = Data()

        // Append key type with 4-byte big-endian length prefix
        var keyTypeLength = UInt32(keyTypeData.count).bigEndian
        wireFormat.append(Data(bytes: &keyTypeLength, count: 4))
        wireFormat.append(keyTypeData)

        // Append public key with 4-byte big-endian length prefix
        var pubKeyLength = UInt32(rawPublicKey.count).bigEndian
        wireFormat.append(Data(bytes: &pubKeyLength, count: 4))
        wireFormat.append(rawPublicKey)

        return keyType + " " + wireFormat.base64EncodedString()
    }
}
