import XCTest
@testable import Claudette

final class TmuxSessionServiceTests: XCTestCase {

    private let service = TmuxSessionService()

    // MARK: - sessionName

    func testSessionNameUsesFirst8CharsLowercasedWithPrefix() {
        let uuid = UUID(uuidString: "ABCDEF01-2345-6789-ABCD-EF0123456789")!
        let name = service.sessionName(profileId: uuid, prefix: "claudette")
        XCTAssertEqual(name, "claudette-abcdef01")
    }

    func testSessionNameWithDifferentPrefix() {
        let uuid = UUID(uuidString: "12345678-AAAA-BBBB-CCCC-DDDDEEEEAAAA")!
        let name = service.sessionName(profileId: uuid, prefix: "test")
        XCTAssertEqual(name, "test-12345678")
    }

    func testSessionNameAlwaysLowercase() {
        let uuid = UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000000")!
        let name = service.sessionName(profileId: uuid, prefix: "app")
        XCTAssertEqual(name, "app-ffffffff")
    }

    func testSessionNameEmptyPrefix() {
        let uuid = UUID(uuidString: "ABCDEF01-2345-6789-ABCD-EF0123456789")!
        let name = service.sessionName(profileId: uuid, prefix: "")
        XCTAssertEqual(name, "-abcdef01")
    }

    // MARK: - checkTmuxCommand

    func testCheckTmuxCommandReturnsWhichTmux() {
        XCTAssertEqual(service.checkTmuxCommand(), "which tmux")
    }

    // MARK: - hasSessionCommand

    func testHasSessionCommandProperlyEscapesSessionName() {
        let cmd = service.hasSessionCommand(sessionName: "my-session")
        XCTAssertEqual(cmd, "tmux has-session -t 'my-session' 2>/dev/null")
    }

    func testHasSessionCommandEscapesSingleQuotes() {
        let cmd = service.hasSessionCommand(sessionName: "it's-a-test")
        XCTAssertEqual(cmd, "tmux has-session -t 'it'\\''s-a-test' 2>/dev/null")
    }

    func testHasSessionCommandWithSimpleName() {
        let cmd = service.hasSessionCommand(sessionName: "test")
        XCTAssertTrue(cmd.contains("tmux has-session -t"))
        XCTAssertTrue(cmd.contains("2>/dev/null"))
    }

    // MARK: - attachCommand

    func testAttachCommandGeneratesCorrectCommand() {
        let cmd = service.attachCommand(sessionName: "my-session")
        XCTAssertEqual(cmd, "tmux attach-session -t 'my-session'")
    }

    func testAttachCommandEscapesSpecialChars() {
        let cmd = service.attachCommand(sessionName: "session with spaces")
        XCTAssertEqual(cmd, "tmux attach-session -t 'session with spaces'")
    }

    // MARK: - newSessionCommand

    func testNewSessionCommandIncludesAllFlags() {
        let cmd = service.newSessionCommand(
            sessionName: "sess",
            directory: "/home/user",
            initialCommand: "claude --continue"
        )
        XCTAssertTrue(cmd.contains("-s 'sess'"))
        XCTAssertTrue(cmd.contains("-c '/home/user'"))
        XCTAssertTrue(cmd.contains("'claude --continue'"))
    }

    func testNewSessionCommandFullFormat() {
        let cmd = service.newSessionCommand(
            sessionName: "test",
            directory: "/tmp",
            initialCommand: "bash"
        )
        XCTAssertEqual(cmd, "tmux new-session -s 'test' -c '/tmp' 'bash'")
    }

    func testNewSessionCommandEscapesDirectoryWithSpaces() {
        let cmd = service.newSessionCommand(
            sessionName: "sess",
            directory: "/home/my user/projects",
            initialCommand: "bash"
        )
        XCTAssertTrue(cmd.contains("-c '/home/my user/projects'"))
    }

    // MARK: - attachOrCreateCommand

    func testAttachOrCreateCommandContainsTmuxHasSessionCheck() {
        let cmd = service.attachOrCreateCommand(
            sessionName: "sess",
            directory: "/home",
            initialCommand: "claude"
        )
        XCTAssertTrue(cmd.contains("tmux has-session -t 'sess'"))
    }

    func testAttachOrCreateCommandContainsFallbackForNoTmux() {
        let cmd = service.attachOrCreateCommand(
            sessionName: "sess",
            directory: "/home",
            initialCommand: "claude"
        )
        XCTAssertTrue(cmd.contains("command -v tmux"))
        XCTAssertTrue(cmd.contains("cd '/home'"))
        XCTAssertTrue(cmd.contains("exec 'claude'"))
    }

    func testAttachOrCreateCommandContainsNewSessionFallback() {
        let cmd = service.attachOrCreateCommand(
            sessionName: "sess",
            directory: "/home",
            initialCommand: "claude"
        )
        XCTAssertTrue(cmd.contains("tmux new-session"))
    }

    func testAttachOrCreateCommandContainsAttachSession() {
        let cmd = service.attachOrCreateCommand(
            sessionName: "sess",
            directory: "/home",
            initialCommand: "claude"
        )
        XCTAssertTrue(cmd.contains("tmux attach-session -t 'sess'"))
    }

    func testAttachOrCreateCommandContainsListPanesCheck() {
        let cmd = service.attachOrCreateCommand(
            sessionName: "sess",
            directory: "/home",
            initialCommand: "claude"
        )
        XCTAssertTrue(cmd.contains("tmux list-panes"))
    }

    func testAttachOrCreateCommandContainsSendKeysRestart() {
        let cmd = service.attachOrCreateCommand(
            sessionName: "sess",
            directory: "/home",
            initialCommand: "claude"
        )
        XCTAssertTrue(cmd.contains("tmux send-keys"))
    }

    // MARK: - shellEscape (tested indirectly)

    func testShellEscapeHandlesStringsWithSingleQuotes() {
        let cmd = service.attachCommand(sessionName: "it's")
        XCTAssertEqual(cmd, "tmux attach-session -t 'it'\\''s'")
    }

    func testShellEscapeHandlesEmptyString() {
        let cmd = service.attachCommand(sessionName: "")
        XCTAssertEqual(cmd, "tmux attach-session -t ''")
    }

    func testShellEscapeHandlesSpecialCharacters() {
        let cmd = service.attachCommand(sessionName: "test session & stuff")
        XCTAssertEqual(cmd, "tmux attach-session -t 'test session & stuff'")
    }

    func testShellEscapeHandlesMultipleSingleQuotes() {
        let cmd = service.attachCommand(sessionName: "it's a 'test'")
        XCTAssertEqual(cmd, "tmux attach-session -t 'it'\\''s a '\\''test'\\'''")
    }

    func testShellEscapeHandlesBackslashes() {
        let cmd = service.attachCommand(sessionName: "path\\to\\dir")
        XCTAssertEqual(cmd, "tmux attach-session -t 'path\\to\\dir'")
    }
}
