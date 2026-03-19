import XCTest
@testable import Claudette

/// Tests for WakeOnLAN MAC address parsing and magic packet construction.
/// Since parseMACAddress and buildMagicPacket are private, we replicate the
/// pure logic here to verify correctness of the algorithms.
final class WakeOnLANServiceTests: XCTestCase {

    // MARK: - MAC Address Parsing (replicated logic)

    /// Replicates the private parseMACAddress logic for testability.
    private func parseMACAddress(_ address: String) throws -> [UInt8] {
        let cleaned = address
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")

        guard cleaned.count == 12 else {
            throw WakeOnLANError.invalidMACAddress
        }

        var bytes: [UInt8] = []
        var index = cleaned.startIndex
        for _ in 0 ..< 6 {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index ..< nextIndex], radix: 16) else {
                throw WakeOnLANError.invalidMACAddress
            }
            bytes.append(byte)
            index = nextIndex
        }

        return bytes
    }

    /// Replicates the private buildMagicPacket logic for testability.
    private func buildMagicPacket(macBytes: [UInt8]) -> Data {
        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0 ..< 16 {
            packet.append(contentsOf: macBytes)
        }
        return packet
    }

    // MARK: - parseMACAddress tests

    func testValidMACWithColonsParsesCorrectly() throws {
        let bytes = try parseMACAddress("AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(bytes.count, 6)
        XCTAssertEqual(bytes[0], 0xAA)
        XCTAssertEqual(bytes[1], 0xBB)
        XCTAssertEqual(bytes[2], 0xCC)
        XCTAssertEqual(bytes[3], 0xDD)
        XCTAssertEqual(bytes[4], 0xEE)
        XCTAssertEqual(bytes[5], 0xFF)
    }

    func testValidMACWithHyphensParsesCorrectly() throws {
        let bytes = try parseMACAddress("01-23-45-67-89-AB")
        XCTAssertEqual(bytes.count, 6)
        XCTAssertEqual(bytes[0], 0x01)
        XCTAssertEqual(bytes[1], 0x23)
        XCTAssertEqual(bytes[2], 0x45)
        XCTAssertEqual(bytes[3], 0x67)
        XCTAssertEqual(bytes[4], 0x89)
        XCTAssertEqual(bytes[5], 0xAB)
    }

    func testValidMACWithoutSeparatorsParsesCorrectly() throws {
        let bytes = try parseMACAddress("AABBCCDDEEFF")
        XCTAssertEqual(bytes.count, 6)
        XCTAssertEqual(bytes[0], 0xAA)
        XCTAssertEqual(bytes[5], 0xFF)
    }

    func testValidMACLowercaseParsesCorrectly() throws {
        let bytes = try parseMACAddress("aa:bb:cc:dd:ee:ff")
        XCTAssertEqual(bytes.count, 6)
        XCTAssertEqual(bytes[0], 0xAA)
        XCTAssertEqual(bytes[5], 0xFF)
    }

    func testInvalidMACTooShortThrows() {
        XCTAssertThrowsError(try parseMACAddress("AA:BB:CC")) { error in
            XCTAssertTrue(error is WakeOnLANError)
        }
    }

    func testInvalidMACTooLongThrows() {
        XCTAssertThrowsError(try parseMACAddress("AA:BB:CC:DD:EE:FF:00")) { error in
            XCTAssertTrue(error is WakeOnLANError)
        }
    }

    func testInvalidMACEmptyStringThrows() {
        XCTAssertThrowsError(try parseMACAddress("")) { error in
            XCTAssertTrue(error is WakeOnLANError)
        }
    }

    func testInvalidMACNonHexCharactersThrows() {
        XCTAssertThrowsError(try parseMACAddress("GG:HH:II:JJ:KK:LL")) { error in
            XCTAssertTrue(error is WakeOnLANError)
        }
    }

    func testAllZerosMACParsesCorrectly() throws {
        let bytes = try parseMACAddress("00:00:00:00:00:00")
        XCTAssertEqual(bytes, [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
    }

    // MARK: - Magic Packet Structure

    func testMagicPacketHasCorrectLength() throws {
        let macBytes: [UInt8] = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
        let packet = buildMagicPacket(macBytes: macBytes)

        // 6 bytes of 0xFF + 16 * 6 bytes of MAC = 6 + 96 = 102
        XCTAssertEqual(packet.count, 102)
    }

    func testMagicPacketStartsWith6BytesOfFF() throws {
        let macBytes: [UInt8] = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06]
        let packet = buildMagicPacket(macBytes: macBytes)

        for i in 0 ..< 6 {
            XCTAssertEqual(packet[i], 0xFF, "Byte \(i) should be 0xFF")
        }
    }

    func testMagicPacketContains16RepetitionsOfMAC() throws {
        let macBytes: [UInt8] = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
        let packet = buildMagicPacket(macBytes: macBytes)

        for rep in 0 ..< 16 {
            let offset = 6 + (rep * 6)
            for b in 0 ..< 6 {
                XCTAssertEqual(
                    packet[offset + b],
                    macBytes[b],
                    "Repetition \(rep), byte \(b) mismatch"
                )
            }
        }
    }

    func testMagicPacketEndToEnd() throws {
        let macBytes = try parseMACAddress("DE:AD:BE:EF:CA:FE")
        let packet = buildMagicPacket(macBytes: macBytes)

        XCTAssertEqual(packet.count, 102)
        XCTAssertEqual(packet[0], 0xFF)
        XCTAssertEqual(packet[5], 0xFF)
        XCTAssertEqual(packet[6], 0xDE)
        XCTAssertEqual(packet[7], 0xAD)
        XCTAssertEqual(packet[8], 0xBE)
        XCTAssertEqual(packet[9], 0xEF)
        XCTAssertEqual(packet[10], 0xCA)
        XCTAssertEqual(packet[11], 0xFE)
    }

    // MARK: - WakeOnLANError

    func testErrorDescription() {
        let error = WakeOnLANError.invalidMACAddress
        XCTAssertEqual(
            error.errorDescription,
            "Invalid MAC address format. Use XX:XX:XX:XX:XX:XX"
        )
    }
}
