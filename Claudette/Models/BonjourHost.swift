import Foundation

struct BonjourHost: Identifiable, Hashable, Sendable {
    let serviceName: String
    let hostname: String
    let port: Int
    let txtRecord: [String: String]

    var id: String {
        serviceName + hostname + String(port)
    }

    var displayName: String {
        if !serviceName.isEmpty {
            return serviceName
        }
        return hostname
    }
}
