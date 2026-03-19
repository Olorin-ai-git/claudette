import XCTest
@testable import Claudette

final class UIColorHexTests: XCTestCase {

    private func assertColorComponents(
        _ color: UIColor,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat = 1.0,
        accuracy: CGFloat = 0.01,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(r, red, accuracy: accuracy, "Red mismatch", file: file, line: line)
        XCTAssertEqual(g, green, accuracy: accuracy, "Green mismatch", file: file, line: line)
        XCTAssertEqual(b, blue, accuracy: accuracy, "Blue mismatch", file: file, line: line)
        XCTAssertEqual(a, alpha, accuracy: accuracy, "Alpha mismatch", file: file, line: line)
    }

    // MARK: - Basic colors

    func testRedFromHexWithHash() {
        let color = UIColor(hex: "#FF0000")
        assertColorComponents(color, red: 1.0, green: 0.0, blue: 0.0)
    }

    func testGreenFromHexWithoutHash() {
        let color = UIColor(hex: "00FF00")
        assertColorComponents(color, red: 0.0, green: 1.0, blue: 0.0)
    }

    func testBlueFromHex() {
        let color = UIColor(hex: "#0000FF")
        assertColorComponents(color, red: 0.0, green: 0.0, blue: 1.0)
    }

    func testWhiteFromHex() {
        let color = UIColor(hex: "#FFFFFF")
        assertColorComponents(color, red: 1.0, green: 1.0, blue: 1.0)
    }

    func testBlackFromHex() {
        let color = UIColor(hex: "#000000")
        assertColorComponents(color, red: 0.0, green: 0.0, blue: 0.0)
    }

    // MARK: - Mixed colors

    func testMixedColorFromHex() {
        let color = UIColor(hex: "#808080")
        assertColorComponents(color, red: 128.0 / 255.0, green: 128.0 / 255.0, blue: 128.0 / 255.0)
    }

    func testSpecificColorFromHex() {
        let color = UIColor(hex: "#1A2B3C")
        assertColorComponents(
            color,
            red: CGFloat(0x1A) / 255.0,
            green: CGFloat(0x2B) / 255.0,
            blue: CGFloat(0x3C) / 255.0
        )
    }

    // MARK: - Whitespace handling

    func testWhitespaceAroundHexIsTrimmed() {
        let color = UIColor(hex: "  #FF0000  ")
        assertColorComponents(color, red: 1.0, green: 0.0, blue: 0.0)
    }

    func testNewlineAroundHexIsTrimmed() {
        let color = UIColor(hex: "\n#00FF00\n")
        assertColorComponents(color, red: 0.0, green: 1.0, blue: 0.0)
    }

    // MARK: - Lowercase hex

    func testLowercaseHex() {
        let color = UIColor(hex: "#ff0000")
        assertColorComponents(color, red: 1.0, green: 0.0, blue: 0.0)
    }

    func testMixedCaseHex() {
        let color = UIColor(hex: "#FfAa00")
        assertColorComponents(
            color,
            red: 1.0,
            green: CGFloat(0xAA) / 255.0,
            blue: 0.0
        )
    }

    // MARK: - Alpha is always 1.0

    func testAlphaIsAlwaysOne() {
        let color = UIColor(hex: "#123456")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(a, 1.0, accuracy: 0.01)
    }
}
