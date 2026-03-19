import Foundation

enum UserTier: String, Codable, CaseIterable, Sendable {
    case free = "free"
    case echo = "echo"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .echo: return "Echo"
        }
    }

    var alternateIconName: String? {
        switch self {
        case .free: return nil // default icon
        case .echo: return "AppIcon-Echo"
        }
    }

    private static let storageKey = "com.olorin.claudette.userTier"

    static func current() -> UserTier {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let tier = UserTier(rawValue: raw)
        else {
            return .free
        }
        return tier
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: UserTier.storageKey)
    }
}
