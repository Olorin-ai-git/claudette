import Foundation

struct ConnectionSettings: Codable, Sendable, Hashable {
    var host: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var projectPath: String
}
