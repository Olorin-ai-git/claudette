import Foundation
import os

@MainActor
final class ProfileListViewModel: ObservableObject {
    @Published var profiles: [ServerProfile] = []
    @Published var errorMessage: String?

    private let profileStore: ProfileStoreProtocol
    private let logger: Logger

    init(profileStore: ProfileStoreProtocol, logger: Logger) {
        self.profileStore = profileStore
        self.logger = logger
    }

    func loadProfiles() {
        do {
            let loaded = try profileStore.loadProfiles()
            profiles = loaded
            logger.info("Loaded \(loaded.count) profiles")
        } catch {
            logger.error("Failed to load profiles: \(error.localizedDescription)")
            errorMessage = "Failed to load profiles: " + error.localizedDescription
        }
    }

    func deleteProfile(_ profile: ServerProfile) {
        do {
            try profileStore.deleteProfile(profile.id)
            profiles.removeAll { $0.id == profile.id }
            logger.info("Deleted profile: \(profile.name, privacy: .public)")
        } catch {
            logger.error("Failed to delete profile: \(error.localizedDescription)")
            errorMessage = "Failed to delete profile: " + error.localizedDescription
        }
    }

    func duplicateProfile(_ profile: ServerProfile) {
        let duplicate = ServerProfile(
            name: profile.name + " Copy",
            host: profile.host,
            port: profile.port,
            username: profile.username,
            authMethod: .password,
            lastProjectPath: profile.lastProjectPath
        )

        do {
            try profileStore.saveProfile(duplicate)
            profiles.append(duplicate)
            logger.info("Duplicated profile: \(profile.name, privacy: .public)")
        } catch {
            logger.error("Failed to duplicate profile: \(error.localizedDescription)")
            errorMessage = "Failed to duplicate profile: " + error.localizedDescription
        }
    }
}
