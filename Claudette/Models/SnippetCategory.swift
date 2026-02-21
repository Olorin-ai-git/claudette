import Foundation

enum SnippetCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case claudeCommands = "Claude Commands"
    case refactoring = "Refactoring"
    case debugging = "Debugging"
    case git = "Git"
    case custom = "Custom"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .claudeCommands: return "terminal"
        case .refactoring: return "arrow.triangle.2.circlepath"
        case .debugging: return "ladybug"
        case .git: return "point.3.filled.connected.trianglepath.dotted"
        case .custom: return "star"
        }
    }
}
