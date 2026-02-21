import Foundation
import os
import UserNotifications

@MainActor
final class PermissionNotificationService: ObservableObject {
    @Published private(set) var isAuthorized: Bool = false

    private let logger: Logger
    private let notificationCenter: UNUserNotificationCenter
    private var buffer: String = ""

    /// Patterns that indicate Claude Code is waiting for permission
    private static let permissionPatterns: [String] = [
        "Allow",
        "Deny",
        "Do you want to",
        "Permission requested",
        "approve",
        "y/n",
        "Y/N",
        "(y)es/(n)o",
    ]

    init(logger: Logger) {
        self.logger = logger
        notificationCenter = UNUserNotificationCenter.current()
    }

    func requestAuthorization() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            logger.info("Notification authorization: \(granted)")
        } catch {
            logger.error("Failed to request notification authorization: \(error.localizedDescription)")
        }
    }

    func processOutput(_ bytes: [UInt8]) {
        guard isAuthorized else { return }
        guard let text = String(bytes: bytes, encoding: .utf8) else { return }
        buffer += text

        // Process lines
        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[buffer.startIndex ..< newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])
            checkForPermissionPrompt(line)
        }

        // Also check partial buffer for permission patterns
        if buffer.count > 200 {
            checkForPermissionPrompt(buffer)
            buffer = ""
        }
    }

    private func checkForPermissionPrompt(_ text: String) {
        let stripped = stripANSI(text)

        let matchCount = Self.permissionPatterns.filter { stripped.contains($0) }.count
        guard matchCount >= 2 else { return }

        sendNotification(prompt: stripped)
    }

    private func sendNotification(prompt: String) {
        let content = UNMutableNotificationContent()
        content.title = "Claude Code Permission"
        content.body = String(prompt.prefix(200))
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        notificationCenter.add(request) { [logger] error in
            if let error {
                logger.error("Failed to deliver notification: \(error.localizedDescription)")
            }
        }

        logger.info("Sent permission notification")
    }

    private func stripANSI(_ text: String) -> String {
        var result = text
        while let range = result.range(of: "\u{1B}\\[[0-9;]*[a-zA-Z]", options: .regularExpression) {
            result.removeSubrange(range)
        }
        return result
    }
}
