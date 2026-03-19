import XCTest
import os
@testable import Claudette

final class AgentActivityParserTests: XCTestCase {

    private func makeParser() -> AgentActivityParser {
        AgentActivityParser(logger: Logger(subsystem: "test", category: "test"))
    }

    private func bytes(_ string: String) -> [UInt8] {
        Array(string.utf8)
    }

    // MARK: - Spawn detection

    @MainActor
    func testProcessOutputParsesSpawnLineAndCreatesRootNode() async {
        let parser = makeParser()

        parser.processOutput(bytes("Launching testbot agent: doing stuff\n"))

        XCTAssertEqual(parser.rootNodes.count, 1)
        XCTAssertEqual(parser.rootNodes.first?.agentType, "testbot")
        XCTAssertEqual(parser.rootNodes.first?.description, "doing stuff")
        XCTAssertFalse(parser.rootNodes.first?.isCompleted ?? true)
    }

    @MainActor
    func testProcessOutputParsesSpawningKeyword() async {
        let parser = makeParser()

        parser.processOutput(bytes("Spawning builder agent: building project\n"))

        XCTAssertEqual(parser.rootNodes.count, 1)
        XCTAssertEqual(parser.rootNodes.first?.agentType, "builder")
    }

    @MainActor
    func testProcessOutputParsesStartingKeyword() async {
        let parser = makeParser()

        parser.processOutput(bytes("Starting analyzer agent: analyzing code\n"))

        XCTAssertEqual(parser.rootNodes.count, 1)
        XCTAssertEqual(parser.rootNodes.first?.agentType, "analyzer")
    }

    // MARK: - Completion detection

    @MainActor
    func testProcessOutputParsesCompletionLineAndMarksNodeCompleted() async {
        let parser = makeParser()

        parser.processOutput(bytes("Launching testbot agent: task\n"))
        parser.processOutput(bytes("Agent testbot completed\n"))

        XCTAssertEqual(parser.rootNodes.count, 1)
        XCTAssertTrue(parser.rootNodes.first?.isCompleted ?? false)
    }

    @MainActor
    func testCompletionWithFinishedKeyword() async {
        let parser = makeParser()

        parser.processOutput(bytes("Launching worker agent: task\n"))
        parser.processOutput(bytes("Agent worker finished\n"))

        XCTAssertTrue(parser.rootNodes.first?.isCompleted ?? false)
    }

    @MainActor
    func testCompletionWithDoneKeyword() async {
        let parser = makeParser()

        parser.processOutput(bytes("Launching worker agent: task\n"))
        parser.processOutput(bytes("Task worker done\n"))

        XCTAssertTrue(parser.rootNodes.first?.isCompleted ?? false)
    }

    // MARK: - Nested agents

    @MainActor
    func testProcessOutputHandlesNestedAgents() async {
        let parser = makeParser()

        parser.processOutput(bytes("Launching parent agent: outer task\n"))
        parser.processOutput(bytes("Launching child agent: inner task\n"))

        XCTAssertEqual(parser.rootNodes.count, 1)
        XCTAssertEqual(parser.rootNodes.first?.agentType, "parent")
        XCTAssertEqual(parser.rootNodes.first?.children.count, 1)
        XCTAssertEqual(parser.rootNodes.first?.children.first?.agentType, "child")
    }

    @MainActor
    func testNestedAgentCompletionDoesNotAffectParent() async {
        let parser = makeParser()

        parser.processOutput(bytes("Launching parent agent: outer\n"))
        parser.processOutput(bytes("Launching child agent: inner\n"))
        parser.processOutput(bytes("Agent child completed\n"))

        XCTAssertFalse(parser.rootNodes.first?.isCompleted ?? true)
        XCTAssertTrue(parser.rootNodes.first?.children.first?.isCompleted ?? false)
    }

    // MARK: - activeAgentCount

    @MainActor
    func testActiveAgentCountIncrementsOnSpawn() async {
        let parser = makeParser()

        XCTAssertEqual(parser.activeAgentCount, 0)
        parser.processOutput(bytes("Launching agent1 agent: task1\n"))
        XCTAssertEqual(parser.activeAgentCount, 1)
        parser.processOutput(bytes("Launching agent2 agent: task2\n"))
        XCTAssertEqual(parser.activeAgentCount, 2)
    }

    @MainActor
    func testActiveAgentCountDecrementsOnComplete() async {
        let parser = makeParser()

        parser.processOutput(bytes("Launching worker agent: task\n"))
        XCTAssertEqual(parser.activeAgentCount, 1)
        parser.processOutput(bytes("Agent worker completed\n"))
        XCTAssertEqual(parser.activeAgentCount, 0)
    }

    @MainActor
    func testActiveAgentCountDoesNotGoBelowZero() async {
        let parser = makeParser()

        // Complete without a matching spawn
        parser.processOutput(bytes("Agent unknown completed\n"))
        XCTAssertEqual(parser.activeAgentCount, 0)
    }

    // MARK: - reset

    @MainActor
    func testResetClearsAllState() async {
        let parser = makeParser()

        parser.processOutput(bytes("Launching agent1 agent: task\n"))
        parser.processOutput(bytes("Launching agent2 agent: task2\n"))
        XCTAssertEqual(parser.rootNodes.count, 1) // agent2 is nested
        XCTAssertEqual(parser.activeAgentCount, 2)

        parser.reset()

        XCTAssertTrue(parser.rootNodes.isEmpty)
        XCTAssertEqual(parser.activeAgentCount, 0)
    }

    // MARK: - ANSI stripping

    @MainActor
    func testStripANSIIsHandledInParsedOutput() async {
        let parser = makeParser()

        let ansiLine = "\u{1B}[32mLaunching\u{1B}[0m colorbot agent: colored task\n"
        parser.processOutput(bytes(ansiLine))

        XCTAssertEqual(parser.rootNodes.count, 1)
        XCTAssertEqual(parser.rootNodes.first?.agentType, "colorbot")
    }

    // MARK: - Task tool pattern

    @MainActor
    func testTaskToolPatternCreatesAgentNode() async {
        let parser = makeParser()

        parser.processOutput(bytes("Task(description: 'researcher')\n"))

        XCTAssertEqual(parser.rootNodes.count, 1)
        XCTAssertEqual(parser.rootNodes.first?.agentType, "researcher")
    }

    @MainActor
    func testTaskToolPatternWithSubagentType() async {
        let parser = makeParser()

        parser.processOutput(bytes("Task(subagent_type: \"analyzer\")\n"))

        XCTAssertEqual(parser.rootNodes.count, 1)
        XCTAssertEqual(parser.rootNodes.first?.agentType, "analyzer")
    }

    // MARK: - Multiple independent agents

    @MainActor
    func testMultipleAgentsTrackedIndependently() async {
        let parser = makeParser()

        parser.processOutput(bytes("Launching alpha agent: task A\n"))
        parser.processOutput(bytes("Agent alpha completed\n"))
        parser.processOutput(bytes("Launching beta agent: task B\n"))

        XCTAssertEqual(parser.rootNodes.count, 2)
        XCTAssertTrue(parser.rootNodes[0].isCompleted)
        XCTAssertFalse(parser.rootNodes[1].isCompleted)
        XCTAssertEqual(parser.activeAgentCount, 1)
    }

    // MARK: - Partial line buffering

    @MainActor
    func testPartialLinesAreBufferedUntilNewline() async {
        let parser = makeParser()

        // Send partial line without newline
        parser.processOutput(bytes("Launching partial"))
        XCTAssertEqual(parser.rootNodes.count, 0)

        // Complete the line
        parser.processOutput(bytes(" agent: finishing up\n"))
        XCTAssertEqual(parser.rootNodes.count, 1)
        XCTAssertEqual(parser.rootNodes.first?.agentType, "partial")
    }

    // MARK: - Non-matching lines

    @MainActor
    func testNonMatchingLinesAreIgnored() async {
        let parser = makeParser()

        parser.processOutput(bytes("Just some regular output\n"))
        parser.processOutput(bytes("Another line of text\n"))

        XCTAssertTrue(parser.rootNodes.isEmpty)
        XCTAssertEqual(parser.activeAgentCount, 0)
    }

    // MARK: - Case insensitive completion

    @MainActor
    func testCompletionIsCaseInsensitive() async {
        let parser = makeParser()

        parser.processOutput(bytes("Launching MyAgent agent: task\n"))
        parser.processOutput(bytes("Agent myagent completed\n"))

        XCTAssertTrue(parser.rootNodes.first?.isCompleted ?? false)
    }
}
