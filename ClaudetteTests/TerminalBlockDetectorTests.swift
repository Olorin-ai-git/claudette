import XCTest
@testable import Claudette

final class TerminalBlockDetectorTests: XCTestCase {

    // MARK: - isPromptLine

    func testIsPromptLineReturnsTrueForDollarPrompt() {
        XCTAssertTrue(TerminalBlockDetector.isPromptLine("user@host $ "))
    }

    func testIsPromptLineReturnsTrueForPercentPrompt() {
        XCTAssertTrue(TerminalBlockDetector.isPromptLine("% "))
    }

    func testIsPromptLineReturnsTrueForHashPrompt() {
        XCTAssertTrue(TerminalBlockDetector.isPromptLine("# "))
    }

    func testIsPromptLineReturnsTrueForAnglePrompt() {
        XCTAssertTrue(TerminalBlockDetector.isPromptLine("> "))
    }

    func testIsPromptLineReturnsTrueForComplexDollarPrompt() {
        XCTAssertTrue(TerminalBlockDetector.isPromptLine("admin@prod-server:/var/log $ "))
    }

    func testIsPromptLineReturnsTrueForRootHashPrompt() {
        XCTAssertTrue(TerminalBlockDetector.isPromptLine("root@server # "))
    }

    func testIsPromptLineReturnsFalseForPlainText() {
        XCTAssertFalse(TerminalBlockDetector.isPromptLine("hello world"))
    }

    func testIsPromptLineReturnsFalseForEmptyString() {
        XCTAssertFalse(TerminalBlockDetector.isPromptLine(""))
    }

    func testIsPromptLineReturnsFalseForWhitespaceOnly() {
        XCTAssertFalse(TerminalBlockDetector.isPromptLine("   "))
    }

    func testIsPromptLineReturnsFalseForSuffixWithoutTrailingSpace() {
        XCTAssertFalse(TerminalBlockDetector.isPromptLine("user@host$"))
    }

    func testIsPromptLineReturnsFalseForDollarSignAlone() {
        XCTAssertFalse(TerminalBlockDetector.isPromptLine("$"))
    }

    func testIsPromptLineStripsANSICodesBeforeChecking() {
        let ansiLine = "\u{1B}[32muser@host\u{1B}[0m $ "
        XCTAssertTrue(TerminalBlockDetector.isPromptLine(ansiLine))
    }

    func testIsPromptLineStripsMultipleANSISequences() {
        let ansiLine = "\u{1B}[1m\u{1B}[34mroot@box\u{1B}[0m # "
        XCTAssertTrue(TerminalBlockDetector.isPromptLine(ansiLine))
    }

    func testIsPromptLineTrimsLeadingWhitespace() {
        XCTAssertTrue(TerminalBlockDetector.isPromptLine("   user@host $ "))
    }

    // MARK: - stripANSI

    func testStripANSIRemovesSingleEscapeSequence() {
        let input = "\u{1B}[31mERROR\u{1B}[0m: something failed"
        let result = TerminalBlockDetector.stripANSI(input)
        XCTAssertEqual(result, "ERROR: something failed")
    }

    func testStripANSIReturnsPlainTextUnchanged() {
        let input = "plain text without escapes"
        let result = TerminalBlockDetector.stripANSI(input)
        XCTAssertEqual(result, input)
    }

    func testStripANSIHandlesMultipleEscapeSequences() {
        let input = "\u{1B}[1m\u{1B}[34mbold blue\u{1B}[0m normal"
        let result = TerminalBlockDetector.stripANSI(input)
        XCTAssertEqual(result, "bold blue normal")
    }

    func testStripANSIHandlesEmptyString() {
        XCTAssertEqual(TerminalBlockDetector.stripANSI(""), "")
    }

    func testStripANSIRemovesColorCodes() {
        let input = "\u{1B}[32mgreen\u{1B}[0m and \u{1B}[31mred\u{1B}[0m"
        let result = TerminalBlockDetector.stripANSI(input)
        XCTAssertEqual(result, "green and red")
    }

    func testStripANSIRemovesCursorMovementCodes() {
        let input = "\u{1B}[2Asome text\u{1B}[K"
        let result = TerminalBlockDetector.stripANSI(input)
        XCTAssertEqual(result, "some text")
    }

    func testStripANSIHandlesConsecutiveEscapeSequences() {
        let input = "\u{1B}[1m\u{1B}[4m\u{1B}[31mtext\u{1B}[0m"
        let result = TerminalBlockDetector.stripANSI(input)
        XCTAssertEqual(result, "text")
    }

    // MARK: - detectBlock

    func testDetectBlockFindsCorrectBoundaries() {
        let lines = [
            "user@host $ ",
            "output line 1",
            "output line 2",
            "user@host $ ",
        ]

        let block = TerminalBlockDetector.detectBlock(lines: lines, atLine: 1)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.startLine, 1)
        XCTAssertEqual(block?.endLine, 2)
        XCTAssertEqual(block?.content, "output line 1\noutput line 2")
    }

    func testDetectBlockReturnsNilForOutOfBoundsIndex() {
        let lines = ["some line"]
        let block = TerminalBlockDetector.detectBlock(lines: lines, atLine: 5)
        XCTAssertNil(block)
    }

    func testDetectBlockReturnsNilForEmptyContentBetweenPrompts() {
        let lines = [
            "user@host $ ",
            "   ",
            "user@host $ ",
        ]
        let block = TerminalBlockDetector.detectBlock(lines: lines, atLine: 1)
        XCTAssertNil(block)
    }

    func testDetectBlockExpandsToFileEdgesWhenNoPrompts() {
        let lines = [
            "line A",
            "line B",
            "line C",
        ]

        let block = TerminalBlockDetector.detectBlock(lines: lines, atLine: 1)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.startLine, 0)
        XCTAssertEqual(block?.endLine, 2)
        XCTAssertEqual(block?.content, "line A\nline B\nline C")
    }

    func testDetectBlockSingleOutputLine() {
        let lines = [
            "user@host $ ",
            "only line",
            "user@host $ ",
        ]

        let block = TerminalBlockDetector.detectBlock(lines: lines, atLine: 1)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.startLine, 1)
        XCTAssertEqual(block?.endLine, 1)
        XCTAssertEqual(block?.content, "only line")
    }

    func testDetectBlockAtPromptLineItself() {
        let lines = [
            "user@host $ ",
            "output",
            "user@host $ ",
        ]
        let block = TerminalBlockDetector.detectBlock(lines: lines, atLine: 0)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.content, "user@host $ ")
    }

    func testDetectBlockReturnsNilForEmptyLinesArray() {
        let block = TerminalBlockDetector.detectBlock(lines: [], atLine: 0)
        XCTAssertNil(block)
    }

    func testDetectBlockMultipleBlocksSelectsCorrectOne() {
        let lines = [
            "user@host $ ",
            "block1 line1",
            "block1 line2",
            "user@host $ ",
            "block2 line1",
            "user@host $ ",
        ]

        let block1 = TerminalBlockDetector.detectBlock(lines: lines, atLine: 1)
        XCTAssertEqual(block1?.content, "block1 line1\nblock1 line2")

        let block2 = TerminalBlockDetector.detectBlock(lines: lines, atLine: 4)
        XCTAssertEqual(block2?.content, "block2 line1")
    }

    func testDetectBlockExtendsToEndWhenNoTrailingPrompt() {
        let lines = [
            "user@host $ ",
            "output line 1",
            "output line 2",
        ]
        let block = TerminalBlockDetector.detectBlock(lines: lines, atLine: 1)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.endLine, 2)
    }

    func testDetectBlockExtendsToStartWhenNoLeadingPrompt() {
        let lines = [
            "output line 1",
            "output line 2",
            "user@host $ ",
        ]
        let block = TerminalBlockDetector.detectBlock(lines: lines, atLine: 1)
        XCTAssertNotNil(block)
        XCTAssertEqual(block?.startLine, 0)
        XCTAssertEqual(block?.endLine, 1)
    }
}
