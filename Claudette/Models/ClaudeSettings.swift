import Foundation

struct ClaudeSettings: Codable, Sendable {
    var hooks: [String: [ClaudeHook]]?

    init(hooks: [String: [ClaudeHook]]? = nil) {
        self.hooks = hooks
    }
}

struct ClaudeHook: Codable, Sendable, Identifiable, Hashable {
    var id: UUID
    var type: String
    var command: String
    var matcher: String?

    init(
        id: UUID = UUID(),
        type: String,
        command: String,
        matcher: String? = nil
    ) {
        self.id = id
        self.type = type
        self.command = command
        self.matcher = matcher
    }

    enum CodingKeys: String, CodingKey {
        case type, command, matcher
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        type = try container.decode(String.self, forKey: .type)
        command = try container.decode(String.self, forKey: .command)
        matcher = try container.decodeIfPresent(String.self, forKey: .matcher)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(command, forKey: .command)
        try container.encodeIfPresent(matcher, forKey: .matcher)
    }
}
