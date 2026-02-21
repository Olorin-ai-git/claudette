import Foundation

enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int, maxAttempts: Int)
    case failed(errorDescription: String)
}
