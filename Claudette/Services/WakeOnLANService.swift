import Foundation
import Network
import os

struct WakeOnLANService: Sendable {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func wake(macAddress: String, broadcastAddress: String = "255.255.255.255") async throws {
        let macBytes = try parseMACAddress(macAddress)
        let magicPacket = buildMagicPacket(macBytes: macBytes)

        let connection = NWConnection(
            host: NWEndpoint.Host(broadcastAddress),
            port: NWEndpoint.Port(rawValue: 9)!,
            using: .udp
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(
                        content: magicPacket,
                        completion: .contentProcessed { error in
                            connection.cancel()
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    )
                case let .failed(error):
                    connection.cancel()
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            connection.start(queue: DispatchQueue.global())
        }

        logger.info("Sent Wake-on-LAN packet to \(macAddress, privacy: .public)")
    }

    private func parseMACAddress(_ address: String) throws -> [UInt8] {
        let cleaned = address
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")

        guard cleaned.count == 12 else {
            throw WakeOnLANError.invalidMACAddress
        }

        var bytes: [UInt8] = []
        var index = cleaned.startIndex
        for _ in 0 ..< 6 {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index ..< nextIndex], radix: 16) else {
                throw WakeOnLANError.invalidMACAddress
            }
            bytes.append(byte)
            index = nextIndex
        }

        return bytes
    }

    private func buildMagicPacket(macBytes: [UInt8]) -> Data {
        // Magic packet: 6 bytes of 0xFF followed by MAC address repeated 16 times
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0 ..< 16 {
            packet.append(contentsOf: macBytes)
        }
        return packet
    }
}

enum WakeOnLANError: LocalizedError {
    case invalidMACAddress

    var errorDescription: String? {
        switch self {
        case .invalidMACAddress:
            return "Invalid MAC address format. Use XX:XX:XX:XX:XX:XX"
        }
    }
}
