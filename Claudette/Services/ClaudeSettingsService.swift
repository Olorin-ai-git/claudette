import Citadel
import CryptoKit
import Foundation
import NIOSSH
import os

@MainActor
final class ClaudeSettingsService: ObservableObject {
    @Published var settings: ClaudeSettings?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let fileBrowserService: RemoteFileBrowserService
    private let logger: Logger
    private let settingsPath = "~/.claude/settings.json"

    init(fileBrowserService: RemoteFileBrowserService, logger: Logger) {
        self.fileBrowserService = fileBrowserService
        self.logger = logger
    }

    func loadSettings() async {
        isLoading = true
        error = nil

        do {
            let data = try await fileBrowserService.readFile(atPath: settingsPath)
            let decoder = JSONDecoder()
            settings = try decoder.decode(ClaudeSettings.self, from: data)
            isLoading = false
            logger.info("Loaded Claude settings")
        } catch {
            // File might not exist yet, which is fine
            settings = ClaudeSettings()
            isLoading = false
            logger.debug("No existing Claude settings found, starting fresh")
        }
    }

    func saveSettings() async {
        guard let settings else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try await fileBrowserService.writeFile(data: data, atPath: settingsPath)
            logger.info("Saved Claude settings")
        } catch {
            self.error = error.localizedDescription
            logger.error("Failed to save Claude settings: \(error.localizedDescription)")
        }
    }
}
