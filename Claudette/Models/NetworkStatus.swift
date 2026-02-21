import Foundation

enum NetworkStatus: Sendable, Equatable {
    case unknown
    case reachable(latencyMs: Double)
    case degraded(latencyMs: Double)
    case unreachable

    var isReachable: Bool {
        switch self {
        case .reachable, .degraded:
            return true
        case .unknown, .unreachable:
            return false
        }
    }

    var latencyMs: Double? {
        switch self {
        case let .reachable(ms), let .degraded(ms):
            return ms
        case .unknown, .unreachable:
            return nil
        }
    }
}
