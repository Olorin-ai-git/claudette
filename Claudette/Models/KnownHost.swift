import CryptoKit
import Foundation

struct KnownHost: Codable, Sendable, Hashable, Identifiable {
    let hostIdentifier: String
    let publicKeyData: Data
    let keyType: String
    let firstSeenAt: Date
    var lastSeenAt: Date

    var id: String {
        hostIdentifier
    }

    var fingerprintSHA256: String {
        let digest = SHA256.hash(data: publicKeyData)
        let base64 = Data(digest).base64EncodedString()
        return "SHA256:" + base64
    }

    init(
        hostIdentifier: String,
        publicKeyData: Data,
        keyType: String,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date = Date()
    ) {
        self.hostIdentifier = hostIdentifier
        self.publicKeyData = publicKeyData
        self.keyType = keyType
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
    }

    static func identifier(host: String, port: Int) -> String {
        host + ":" + String(port)
    }
}
