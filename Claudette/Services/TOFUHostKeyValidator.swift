import Citadel
import CryptoKit
import Foundation
import NIOCore
import NIOSSH
import os

protocol HostKeyVerificationDelegate: AnyObject, Sendable {
    func verifyHostKey(
        result: HostKeyVerificationResult,
        fingerprint: String,
        hostIdentifier: String
    ) async -> Bool
}

final class TOFUHostKeyValidator: NIOSSHClientServerAuthenticationDelegate, @unchecked Sendable {
    private let hostKeyStore: HostKeyStoreProtocol
    private let logger: Logger
    var host: String = ""
    var port: Int = 22
    weak var delegate: HostKeyVerificationDelegate?

    init(hostKeyStore: HostKeyStoreProtocol, logger: Logger) {
        self.hostKeyStore = hostKeyStore
        self.logger = logger
    }

    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        let hostIdentifier = KnownHost.identifier(host: host, port: port)
        let keyData = hostKey.rawRepresentation
        let keyType = hostKey.keyType

        let digest = SHA256.hash(data: keyData)
        let fingerprint = "SHA256:" + Data(digest).base64EncodedString()

        logger.info("Validating host key for \(hostIdentifier, privacy: .public): \(fingerprint, privacy: .public)")

        if let knownHost = hostKeyStore.knownHost(forIdentifier: hostIdentifier) {
            if knownHost.publicKeyData == keyData {
                // Key matches — trusted
                logger.info("Host key matches known key for \(hostIdentifier, privacy: .public)")
                var updated = knownHost
                updated.lastSeenAt = Date()
                try? hostKeyStore.storeHost(updated)
                validationCompletePromise.succeed(())
                return
            } else {
                // Key changed — dangerous
                let previousFingerprint = knownHost.fingerprintSHA256
                logger.warning("HOST KEY CHANGED for \(hostIdentifier, privacy: .public)")

                guard let delegate else {
                    logger.error("No delegate to handle key change verification")
                    validationCompletePromise.fail(HostKeyRejectedError())
                    return
                }

                let result = HostKeyVerificationResult.keyChanged(
                    previousFingerprint: previousFingerprint,
                    newFingerprint: fingerprint
                )

                Task { [weak self] in
                    let accepted = await delegate.verifyHostKey(
                        result: result,
                        fingerprint: fingerprint,
                        hostIdentifier: hostIdentifier
                    )

                    if accepted {
                        let newHost = KnownHost(
                            hostIdentifier: hostIdentifier,
                            publicKeyData: keyData,
                            keyType: keyType
                        )
                        try? self?.hostKeyStore.storeHost(newHost)
                        self?.logger.info("User accepted new key for \(hostIdentifier, privacy: .public)")
                        validationCompletePromise.succeed(())
                    } else {
                        validationCompletePromise.fail(HostKeyRejectedError())
                    }
                }
            }
        } else {
            // New host — ask user
            logger.info("New host encountered: \(hostIdentifier, privacy: .public)")

            guard let delegate else {
                logger.error("No delegate to handle new host verification")
                validationCompletePromise.fail(HostKeyRejectedError())
                return
            }

            Task { [weak self] in
                let accepted = await delegate.verifyHostKey(
                    result: .newHost,
                    fingerprint: fingerprint,
                    hostIdentifier: hostIdentifier
                )

                if accepted {
                    let newHost = KnownHost(
                        hostIdentifier: hostIdentifier,
                        publicKeyData: keyData,
                        keyType: keyType
                    )
                    try? self?.hostKeyStore.storeHost(newHost)
                    self?.logger.info("User trusted new host: \(hostIdentifier, privacy: .public)")
                    validationCompletePromise.succeed(())
                } else {
                    validationCompletePromise.fail(HostKeyRejectedError())
                }
            }
        }
    }

    func makeValidator(host: String, port: Int) -> SSHHostKeyValidator {
        self.host = host
        self.port = port
        return .custom(self)
    }
}

struct HostKeyRejectedError: Error {}

extension NIOSSHPublicKey {
    var rawRepresentation: Data {
        var buffer = ByteBufferAllocator().buffer(capacity: 256)
        _ = write(to: &buffer)
        let bytes = buffer.readBytes(length: buffer.readableBytes) ?? []
        return Data(bytes)
    }

    var keyType: String {
        let data = rawRepresentation
        guard data.count >= 4 else { return "unknown" }

        let typeLength = Int(data[0]) << 24 | Int(data[1]) << 16 | Int(data[2]) << 8 | Int(data[3])
        guard data.count >= 4 + typeLength else { return "unknown" }

        let typeData = data[4 ..< (4 + typeLength)]
        return String(data: typeData, encoding: .utf8) ?? "unknown"
    }
}
