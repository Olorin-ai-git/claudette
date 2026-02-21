import Foundation

enum AuthMethod: Codable, Sendable, Hashable {
    case password
    case generatedKey(keyTag: String)
    case importedKey(keyTag: String)

    var displayName: String {
        switch self {
        case .password:
            return "Password"
        case .generatedKey:
            return "Generated SSH Key"
        case .importedKey:
            return "Imported SSH Key"
        }
    }

    var isKeyBased: Bool {
        switch self {
        case .password:
            return false
        case .generatedKey, .importedKey:
            return true
        }
    }

    var keyTag: String? {
        switch self {
        case .password:
            return nil
        case let .generatedKey(tag), let .importedKey(tag):
            return tag
        }
    }
}
