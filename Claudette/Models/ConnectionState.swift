import Foundation

enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case failed(errorDescription: String)
}
