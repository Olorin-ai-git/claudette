import Foundation
import os
import UIKit

@MainActor
final class AuthURLInterceptor: ObservableObject {
    @Published private(set) var detectedURL: String?

    private let logger: Logger
    private var lineBuffer: String = ""
    private var lastCopiedURL: String?
    private let authDomains = ["anthropic.com", "claude.ai"]

    init(logger: Logger) {
        self.logger = logger
    }

    func processOutput(_ bytes: [UInt8]) {
        guard let text = String(bytes: bytes, encoding: .utf8) else { return }
        lineBuffer += text

        while let nlIndex = lineBuffer.firstIndex(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex ..< nlIndex])
            lineBuffer = String(lineBuffer[lineBuffer.index(after: nlIndex)...])
            scanForAuthURL(in: line)
        }

        // Scan partial buffer for URLs that arrive without trailing newline
        if lineBuffer.count > 20 {
            scanForAuthURL(in: lineBuffer)
        }
    }

    func clearDetectedURL() {
        detectedURL = nil
    }

    private func scanForAuthURL(in text: String) {
        let cleaned = stripANSI(text)

        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return }

        let range = NSRange(cleaned.startIndex ..< cleaned.endIndex, in: cleaned)
        let matches = detector.matches(in: cleaned, range: range)

        for match in matches {
            guard let url = match.url,
                  let host = url.host?.lowercased()
            else { continue }

            let isAuthDomain = authDomains.contains(where: { host.contains($0) })
            guard isAuthDomain else { continue }

            let urlString = url.absoluteString
            guard urlString != lastCopiedURL else { continue }

            lastCopiedURL = urlString
            UIPasteboard.general.string = urlString
            detectedURL = urlString
            logger.info("Auth URL detected and copied to clipboard")
            return
        }
    }

    private func stripANSI(_ text: String) -> String {
        text.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*[a-zA-Z]",
            with: "",
            options: .regularExpression
        )
    }
}
