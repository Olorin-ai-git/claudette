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

        // Scan partial buffer for URLs that arrive without trailing newline.
        // Use a generous threshold so we don't match a truncated URL that is
        // still being received (e.g. missing redirect_uri tail).
        if lineBuffer.count > 200 {
            scanForAuthURL(in: lineBuffer)
        }
    }

    func clearDetectedURL() {
        detectedURL = nil
    }

    private func scanForAuthURL(in text: String) {
        let cleaned = stripANSI(text)

        // Use regex to extract full URLs preserving query parameters.
        // NSDataDetector is known to truncate URLs at query-string boundaries
        // (e.g. dropping redirect_uri), so we match with a permissive regex instead.
        let urlPattern = "https?://[A-Za-z0-9\\-._~:/?#\\[\\]@!$&'()*+,;=%]+"
        guard let regex = try? NSRegularExpression(pattern: urlPattern) else { return }

        let range = NSRange(cleaned.startIndex ..< cleaned.endIndex, in: cleaned)
        let matches = regex.matches(in: cleaned, range: range)

        for match in matches {
            guard let swiftRange = Range(match.range, in: cleaned) else { continue }
            // Trim trailing punctuation that may have been swept up by the regex
            var urlString = String(cleaned[swiftRange])
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?)>\"'"))
            // Strip a trailing single-quote if present (terminal quoting artefact)
            if urlString.hasSuffix("'") {
                urlString = String(urlString.dropLast())
            }

            guard let url = URL(string: urlString),
                  let host = url.host?.lowercased()
            else { continue }

            let isAuthDomain = authDomains.contains(where: { host.contains($0) })
            guard isAuthDomain else { continue }

            guard urlString != lastCopiedURL else { continue }

            lastCopiedURL = urlString
            UIPasteboard.general.string = urlString
            detectedURL = urlString
            logger.info("Auth URL detected and copied to clipboard")
            return
        }
    }

    private func stripANSI(_ text: String) -> String {
        // Strip CSI sequences:  ESC [ <params> <letter>
        // Strip OSC sequences:  ESC ] ... (ST | BEL)   — used for hyperlinks (OSC 8)
        // Strip simple escapes: ESC followed by single char (e.g. ESC = , ESC >)
        var result = text.replacingOccurrences(
            of: "\u{1B}\\[[0-9;]*[a-zA-Z]",
            with: "",
            options: .regularExpression
        )
        // OSC: ESC ] ... terminated by ST (ESC \) or BEL (\x07)
        result = result.replacingOccurrences(
            of: "\u{1B}\\][^\u{07}\u{1B}]*(?:\u{07}|\u{1B}\\\\)",
            with: "",
            options: .regularExpression
        )
        // Simple two-char escapes: ESC <single printable char>
        result = result.replacingOccurrences(
            of: "\u{1B}[^\\[\\]]",
            with: "",
            options: .regularExpression
        )
        return result
    }
}
