import Foundation

struct ProjectEntry: Codable, Sendable, Hashable, Identifiable {
    let name: String
    let folder: String

    var id: String {
        folder
    }
}
