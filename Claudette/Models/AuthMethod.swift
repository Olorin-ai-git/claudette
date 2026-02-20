import Foundation

enum AuthMethod: Codable, Sendable, Hashable {
    case password
    case privateKey(keyTag: String)
}
