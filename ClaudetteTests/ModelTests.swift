import CryptoKit
import XCTest
@testable import Claudette

// MARK: - AuthMethod Tests

final class AuthMethodTests: XCTestCase {

    func testPasswordDisplayName() {
        XCTAssertEqual(AuthMethod.password.displayName, "Password")
    }

    func testGeneratedKeyDisplayName() {
        XCTAssertEqual(AuthMethod.generatedKey(keyTag: "tag1").displayName, "Generated SSH Key")
    }

    func testImportedKeyDisplayName() {
        XCTAssertEqual(AuthMethod.importedKey(keyTag: "tag2").displayName, "Imported SSH Key")
    }

    func testPasswordIsKeyBasedIsFalse() {
        XCTAssertFalse(AuthMethod.password.isKeyBased)
    }

    func testGeneratedKeyIsKeyBasedIsTrue() {
        XCTAssertTrue(AuthMethod.generatedKey(keyTag: "tag").isKeyBased)
    }

    func testImportedKeyIsKeyBasedIsTrue() {
        XCTAssertTrue(AuthMethod.importedKey(keyTag: "tag").isKeyBased)
    }

    func testPasswordKeyTagIsNil() {
        XCTAssertNil(AuthMethod.password.keyTag)
    }

    func testGeneratedKeyKeyTagReturnsTag() {
        XCTAssertEqual(AuthMethod.generatedKey(keyTag: "my-tag").keyTag, "my-tag")
    }

    func testImportedKeyKeyTagReturnsTag() {
        XCTAssertEqual(AuthMethod.importedKey(keyTag: "other-tag").keyTag, "other-tag")
    }

    func testAuthMethodEquality() {
        XCTAssertEqual(AuthMethod.password, AuthMethod.password)
        XCTAssertEqual(
            AuthMethod.generatedKey(keyTag: "a"),
            AuthMethod.generatedKey(keyTag: "a")
        )
        XCTAssertNotEqual(
            AuthMethod.generatedKey(keyTag: "a"),
            AuthMethod.generatedKey(keyTag: "b")
        )
        XCTAssertNotEqual(
            AuthMethod.generatedKey(keyTag: "a"),
            AuthMethod.importedKey(keyTag: "a")
        )
    }
}

// MARK: - BonjourHost Tests

final class BonjourHostTests: XCTestCase {

    func testIdConcatenatesServiceNameHostnamePort() {
        let host = BonjourHost(
            serviceName: "MyServer",
            hostname: "server.local",
            port: 22,
            txtRecord: [:]
        )
        XCTAssertEqual(host.id, "MyServerserver.local22")
    }

    func testDisplayNameReturnsServiceNameWhenNonEmpty() {
        let host = BonjourHost(
            serviceName: "MyServer",
            hostname: "server.local",
            port: 22,
            txtRecord: [:]
        )
        XCTAssertEqual(host.displayName, "MyServer")
    }

    func testDisplayNameFallsBackToHostnameWhenServiceNameEmpty() {
        let host = BonjourHost(
            serviceName: "",
            hostname: "server.local",
            port: 22,
            txtRecord: [:]
        )
        XCTAssertEqual(host.displayName, "server.local")
    }

    func testIdUniquenessWithDifferentPorts() {
        let host1 = BonjourHost(serviceName: "A", hostname: "h", port: 22, txtRecord: [:])
        let host2 = BonjourHost(serviceName: "A", hostname: "h", port: 2222, txtRecord: [:])
        XCTAssertNotEqual(host1.id, host2.id)
    }
}

// MARK: - NetworkStatus Tests

final class NetworkStatusTests: XCTestCase {

    func testUnknownIsReachableIsFalse() {
        XCTAssertFalse(NetworkStatus.unknown.isReachable)
    }

    func testReachableIsReachableIsTrue() {
        XCTAssertTrue(NetworkStatus.reachable(latencyMs: 10.0).isReachable)
    }

    func testDegradedIsReachableIsTrue() {
        XCTAssertTrue(NetworkStatus.degraded(latencyMs: 500.0).isReachable)
    }

    func testUnreachableIsReachableIsFalse() {
        XCTAssertFalse(NetworkStatus.unreachable.isReachable)
    }

    func testReachableLatencyMsReturnsValue() {
        XCTAssertEqual(NetworkStatus.reachable(latencyMs: 42.5).latencyMs, 42.5)
    }

    func testDegradedLatencyMsReturnsValue() {
        XCTAssertEqual(NetworkStatus.degraded(latencyMs: 300.0).latencyMs, 300.0)
    }

    func testUnknownLatencyMsReturnsNil() {
        XCTAssertNil(NetworkStatus.unknown.latencyMs)
    }

    func testUnreachableLatencyMsReturnsNil() {
        XCTAssertNil(NetworkStatus.unreachable.latencyMs)
    }

    func testEquality() {
        XCTAssertEqual(NetworkStatus.unknown, NetworkStatus.unknown)
        XCTAssertEqual(NetworkStatus.unreachable, NetworkStatus.unreachable)
        XCTAssertEqual(
            NetworkStatus.reachable(latencyMs: 10),
            NetworkStatus.reachable(latencyMs: 10)
        )
        XCTAssertNotEqual(
            NetworkStatus.reachable(latencyMs: 10),
            NetworkStatus.reachable(latencyMs: 20)
        )
        XCTAssertNotEqual(
            NetworkStatus.reachable(latencyMs: 10),
            NetworkStatus.degraded(latencyMs: 10)
        )
    }
}

// MARK: - ClaudeResourceType Tests

final class ClaudeResourceTypeTests: XCTestCase {

    func testCommandDisplayTitle() {
        XCTAssertEqual(ClaudeResourceType.command.displayTitle, "Commands")
    }

    func testSkillDisplayTitle() {
        XCTAssertEqual(ClaudeResourceType.skill.displayTitle, "Skills")
    }

    func testAgentDisplayTitle() {
        XCTAssertEqual(ClaudeResourceType.agent.displayTitle, "Agents")
    }

    func testCommandIcon() {
        XCTAssertEqual(ClaudeResourceType.command.icon, "terminal")
    }

    func testSkillIcon() {
        XCTAssertEqual(ClaudeResourceType.skill.icon, "star")
    }

    func testAgentIcon() {
        XCTAssertEqual(ClaudeResourceType.agent.icon, "cpu")
    }

    func testCommandDirectoryName() {
        XCTAssertEqual(ClaudeResourceType.command.directoryName, "commands")
    }

    func testSkillDirectoryName() {
        XCTAssertEqual(ClaudeResourceType.skill.directoryName, "skills")
    }

    func testAgentDirectoryName() {
        XCTAssertEqual(ClaudeResourceType.agent.directoryName, "agents")
    }
}

// MARK: - ClaudeResource Tests

final class ClaudeResourceTests: XCTestCase {

    private func makeResource(
        name: String,
        type: ClaudeResourceType,
        description: String? = nil
    ) -> ClaudeResource {
        ClaudeResource(
            id: "test-id",
            name: name,
            type: type,
            description: description,
            isUserInvocable: true,
            filePath: "/path/to/resource"
        )
    }

    func testDisplayNameStripsMdExtension() {
        let resource = makeResource(name: "commit.md", type: .command)
        XCTAssertEqual(resource.displayName, "commit")
    }

    func testDisplayNameReplacesHyphensWithSpaces() {
        let resource = makeResource(name: "my-cool-command.md", type: .command)
        XCTAssertEqual(resource.displayName, "my cool command")
    }

    func testDisplayNameReplacesUnderscoresWithSpaces() {
        let resource = makeResource(name: "my_cool_command.md", type: .command)
        XCTAssertEqual(resource.displayName, "my cool command")
    }

    func testDisplayNameReplacesBothHyphensAndUnderscores() {
        let resource = makeResource(name: "my-cool_command.md", type: .command)
        XCTAssertEqual(resource.displayName, "my cool command")
    }

    func testInvokeCommandReturnsSlashForCommands() {
        let resource = makeResource(name: "commit.md", type: .command)
        XCTAssertEqual(resource.invokeCommand, "/commit")
    }

    func testInvokeCommandReturnsSlashForSkills() {
        let resource = makeResource(name: "review.md", type: .skill)
        XCTAssertEqual(resource.invokeCommand, "/review")
    }

    func testInvokeCommandReturnsBareSlugForAgents() {
        let resource = makeResource(name: "librarian-agent.md", type: .agent)
        XCTAssertEqual(resource.invokeCommand, "librarian-agent")
    }

    func testTriggerCommandReturnsSlashForCommands() {
        let resource = makeResource(name: "commit.md", type: .command)
        XCTAssertEqual(resource.triggerCommand, "/commit")
    }

    func testTriggerCommandReturnsSlashForSkills() {
        let resource = makeResource(name: "review.md", type: .skill)
        XCTAssertEqual(resource.triggerCommand, "/review")
    }

    func testTriggerCommandForAgentWithDescription() {
        let resource = makeResource(
            name: "librarian.md",
            type: .agent,
            description: "Manages the library catalog"
        )
        XCTAssertEqual(
            resource.triggerCommand,
            "Run the librarian agent: Manages the library catalog"
        )
    }

    func testTriggerCommandForAgentWithoutDescription() {
        let resource = makeResource(name: "librarian.md", type: .agent, description: nil)
        XCTAssertEqual(resource.triggerCommand, "Run the librarian agent")
    }

    func testTriggerCommandForAgentWithEmptyDescription() {
        let resource = makeResource(name: "librarian.md", type: .agent, description: "")
        XCTAssertEqual(resource.triggerCommand, "Run the librarian agent")
    }
}

// MARK: - SnippetCategory Tests

final class SnippetCategoryTests: XCTestCase {

    func testClaudeCommandsSystemImage() {
        XCTAssertEqual(SnippetCategory.claudeCommands.systemImage, "terminal")
    }

    func testRefactoringSystemImage() {
        XCTAssertEqual(SnippetCategory.refactoring.systemImage, "arrow.triangle.2.circlepath")
    }

    func testDebuggingSystemImage() {
        XCTAssertEqual(SnippetCategory.debugging.systemImage, "ladybug")
    }

    func testGitSystemImage() {
        XCTAssertEqual(SnippetCategory.git.systemImage, "point.3.filled.connected.trianglepath.dotted")
    }

    func testCustomSystemImage() {
        XCTAssertEqual(SnippetCategory.custom.systemImage, "star")
    }

    func testIdReturnsRawValue() {
        XCTAssertEqual(SnippetCategory.claudeCommands.id, "Claude Commands")
        XCTAssertEqual(SnippetCategory.refactoring.id, "Refactoring")
        XCTAssertEqual(SnippetCategory.debugging.id, "Debugging")
        XCTAssertEqual(SnippetCategory.git.id, "Git")
        XCTAssertEqual(SnippetCategory.custom.id, "Custom")
    }

    func testAllCasesContainsAllCategories() {
        XCTAssertEqual(SnippetCategory.allCases.count, 5)
    }
}

// MARK: - KnownHost Tests

final class KnownHostTests: XCTestCase {

    func testIdentifierGeneratesHostPortFormat() {
        let id = KnownHost.identifier(host: "example.com", port: 22)
        XCTAssertEqual(id, "example.com:22")
    }

    func testIdentifierWithNonStandardPort() {
        let id = KnownHost.identifier(host: "myserver.local", port: 2222)
        XCTAssertEqual(id, "myserver.local:2222")
    }

    func testFingerprintSHA256ComputesCorrectHash() {
        let data = Data("test-public-key-data".utf8)
        let host = KnownHost(
            hostIdentifier: "host:22",
            publicKeyData: data,
            keyType: "ssh-ed25519"
        )

        let digest = SHA256.hash(data: data)
        let expectedBase64 = Data(digest).base64EncodedString()
        let expectedFingerprint = "SHA256:" + expectedBase64

        XCTAssertEqual(host.fingerprintSHA256, expectedFingerprint)
        XCTAssertTrue(host.fingerprintSHA256.hasPrefix("SHA256:"))
    }

    func testFingerprintSHA256ConsistentForSameData() {
        let data = Data("consistent-key".utf8)
        let host1 = KnownHost(hostIdentifier: "h:22", publicKeyData: data, keyType: "ssh-rsa")
        let host2 = KnownHost(hostIdentifier: "h:22", publicKeyData: data, keyType: "ssh-rsa")
        XCTAssertEqual(host1.fingerprintSHA256, host2.fingerprintSHA256)
    }

    func testFingerprintSHA256DiffersForDifferentData() {
        let host1 = KnownHost(
            hostIdentifier: "h:22",
            publicKeyData: Data("key1".utf8),
            keyType: "ssh-rsa"
        )
        let host2 = KnownHost(
            hostIdentifier: "h:22",
            publicKeyData: Data("key2".utf8),
            keyType: "ssh-rsa"
        )
        XCTAssertNotEqual(host1.fingerprintSHA256, host2.fingerprintSHA256)
    }

    func testIdReturnsHostIdentifier() {
        let host = KnownHost(
            hostIdentifier: "myhost:22",
            publicKeyData: Data(),
            keyType: "ssh-rsa"
        )
        XCTAssertEqual(host.id, "myhost:22")
    }
}

// MARK: - ServerProfile Tests

final class ServerProfileTests: XCTestCase {

    func testToConnectionSettingsMapsFieldsCorrectly() {
        let profile = ServerProfile(
            name: "Test Server",
            host: "example.com",
            port: 2222,
            username: "admin",
            authMethod: .password
        )

        let settings = profile.toConnectionSettings(projectPath: "/home/admin/project")

        XCTAssertEqual(settings.host, "example.com")
        XCTAssertEqual(settings.port, 2222)
        XCTAssertEqual(settings.username, "admin")
        XCTAssertEqual(settings.authMethod, .password)
        XCTAssertEqual(settings.projectPath, "/home/admin/project")
    }

    func testToConnectionSettingsWithKeyAuth() {
        let profile = ServerProfile(
            name: "Key Server",
            host: "key.example.com",
            port: 22,
            username: "user",
            authMethod: .generatedKey(keyTag: "com.app.key")
        )

        let settings = profile.toConnectionSettings(projectPath: "/root")

        XCTAssertEqual(settings.authMethod, .generatedKey(keyTag: "com.app.key"))
        XCTAssertEqual(settings.host, "key.example.com")
        XCTAssertEqual(settings.port, 22)
        XCTAssertEqual(settings.username, "user")
        XCTAssertEqual(settings.projectPath, "/root")
    }

    func testToConnectionSettingsUsesProvidedProjectPath() {
        let profile = ServerProfile(
            name: "Server",
            host: "host",
            port: 22,
            username: "u",
            authMethod: .password,
            lastProjectPath: "/old/path"
        )

        let settings = profile.toConnectionSettings(projectPath: "/new/path")
        XCTAssertEqual(settings.projectPath, "/new/path")
    }
}

// MARK: - ClaudeHook Tests

final class ClaudeHookTests: XCTestCase {

    func testClaudeHookEncodesWithoutId() throws {
        let hook = ClaudeHook(type: "command", command: "echo hello", matcher: "*.swift")
        let data = try JSONEncoder().encode(hook)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNil(json["id"])
        XCTAssertEqual(json["type"] as? String, "command")
        XCTAssertEqual(json["command"] as? String, "echo hello")
        XCTAssertEqual(json["matcher"] as? String, "*.swift")
    }

    func testClaudeHookEncodesWithoutMatcherWhenNil() throws {
        let hook = ClaudeHook(type: "command", command: "echo hi", matcher: nil)
        let data = try JSONEncoder().encode(hook)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNil(json["matcher"])
    }

    func testClaudeHookDecodesAndGeneratesNewUUID() throws {
        let json = """
        {"type": "command", "command": "echo test"}
        """
        let data = json.data(using: .utf8)!

        let hook1 = try JSONDecoder().decode(ClaudeHook.self, from: data)
        let hook2 = try JSONDecoder().decode(ClaudeHook.self, from: data)

        XCTAssertEqual(hook1.type, "command")
        XCTAssertEqual(hook1.command, "echo test")
        XCTAssertNil(hook1.matcher)
        XCTAssertNotEqual(hook1.id, hook2.id)
    }

    func testClaudeHookDecodesWithMatcher() throws {
        let json = """
        {"type": "shell", "command": "lint", "matcher": "*.py"}
        """
        let data = json.data(using: .utf8)!
        let hook = try JSONDecoder().decode(ClaudeHook.self, from: data)

        XCTAssertEqual(hook.type, "shell")
        XCTAssertEqual(hook.command, "lint")
        XCTAssertEqual(hook.matcher, "*.py")
    }

    func testClaudeHookRoundTrip() throws {
        let original = ClaudeHook(type: "command", command: "test", matcher: "*.ts")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ClaudeHook.self, from: data)

        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.command, original.command)
        XCTAssertEqual(decoded.matcher, original.matcher)
        // id should differ because decode generates a new UUID
        XCTAssertNotEqual(decoded.id, original.id)
    }
}

// MARK: - ClaudeSettings Tests

final class ClaudeSettingsTests: XCTestCase {

    func testClaudeSettingsRoundTripsThroughJSON() throws {
        let hook = ClaudeHook(type: "command", command: "echo hi", matcher: nil)
        let settings = ClaudeSettings(hooks: ["PreToolUse": [hook]])

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ClaudeSettings.self, from: data)

        XCTAssertNotNil(decoded.hooks)
        XCTAssertEqual(decoded.hooks?["PreToolUse"]?.count, 1)
        XCTAssertEqual(decoded.hooks?["PreToolUse"]?.first?.type, "command")
        XCTAssertEqual(decoded.hooks?["PreToolUse"]?.first?.command, "echo hi")
    }

    func testClaudeSettingsWithNilHooks() throws {
        let settings = ClaudeSettings(hooks: nil)
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ClaudeSettings.self, from: data)
        XCTAssertNil(decoded.hooks)
    }

    func testClaudeSettingsWithMultipleHookCategories() throws {
        let hook1 = ClaudeHook(type: "command", command: "cmd1")
        let hook2 = ClaudeHook(type: "shell", command: "cmd2")
        let settings = ClaudeSettings(hooks: [
            "PreToolUse": [hook1],
            "PostToolUse": [hook2],
        ])

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ClaudeSettings.self, from: data)

        XCTAssertEqual(decoded.hooks?.count, 2)
        XCTAssertEqual(decoded.hooks?["PreToolUse"]?.first?.command, "cmd1")
        XCTAssertEqual(decoded.hooks?["PostToolUse"]?.first?.command, "cmd2")
    }

    func testClaudeSettingsWithEmptyHooksDictionary() throws {
        let settings = ClaudeSettings(hooks: [:])
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ClaudeSettings.self, from: data)
        XCTAssertNotNil(decoded.hooks)
        XCTAssertTrue(decoded.hooks?.isEmpty ?? false)
    }
}

// MARK: - AgentTreeNode Tests

final class AgentTreeNodeTests: XCTestCase {

    func testDisplayDurationShowsSecondsFormatUnderSixty() {
        let node = AgentTreeNode(
            id: "1",
            agentType: "test",
            description: "desc",
            startTime: Date().addingTimeInterval(-30)
        )
        let display = node.displayDuration
        XCTAssertTrue(display.hasSuffix("s"))
        XCTAssertFalse(display.contains("m"))
    }

    func testDisplayDurationShowsMinutesFormatOverSixty() {
        let node = AgentTreeNode(
            id: "2",
            agentType: "test",
            description: "desc",
            startTime: Date().addingTimeInterval(-125)
        )
        let display = node.displayDuration
        XCTAssertTrue(display.contains("m"))
        XCTAssertTrue(display.contains("s"))
    }

    func testDisplayDurationAtExactlySixtySeconds() {
        let node = AgentTreeNode(
            id: "3",
            agentType: "test",
            description: "desc",
            startTime: Date().addingTimeInterval(-60)
        )
        let display = node.displayDuration
        XCTAssertTrue(display.contains("m"))
    }

    func testInitialState() {
        let node = AgentTreeNode(
            id: "4",
            agentType: "builder",
            description: "Build the project"
        )
        XCTAssertEqual(node.id, "4")
        XCTAssertEqual(node.agentType, "builder")
        XCTAssertEqual(node.description, "Build the project")
        XCTAssertFalse(node.isCompleted)
        XCTAssertTrue(node.children.isEmpty)
    }

    func testChildrenCanBeAdded() {
        let parent = AgentTreeNode(id: "p", agentType: "parent", description: "parent")
        let child = AgentTreeNode(id: "c", agentType: "child", description: "child")
        parent.children.append(child)

        XCTAssertEqual(parent.children.count, 1)
        XCTAssertEqual(parent.children.first?.id, "c")
    }

    func testIsCompletedCanBeToggled() {
        let node = AgentTreeNode(id: "n", agentType: "t", description: "d")
        XCTAssertFalse(node.isCompleted)
        node.isCompleted = true
        XCTAssertTrue(node.isCompleted)
    }
}
