import Foundation
import os

protocol ProfileStoreProtocol: Sendable {
    func loadProfiles() throws -> [ServerProfile]
    func saveProfile(_ profile: ServerProfile) throws
    func deleteProfile(_ profileId: UUID) throws
    func updateProfile(_ profile: ServerProfile) throws
}

final class ProfileStore: ProfileStoreProtocol, @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.olorin.claudette.profilestore")
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("com.olorin.claudette", isDirectory: true)

        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }

        fileURL = appDirectory.appendingPathComponent("profiles.json")
        let path = fileURL.path
        logger.info("Profile store path: \(path, privacy: .public)")
    }

    func loadProfiles() throws -> [ServerProfile] {
        try queue.sync {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return []
            }

            let data = try Data(contentsOf: fileURL)
            let profiles = try JSONDecoder().decode([ServerProfile].self, from: data)
            logger.info("Loaded \(profiles.count) profiles")
            return profiles
        }
    }

    func saveProfile(_ profile: ServerProfile) throws {
        try queue.sync {
            var profiles = (try? loadProfilesUnsafe()) ?? []
            profiles.removeAll { $0.id == profile.id }
            profiles.append(profile)
            try writeProfiles(profiles)
            logger.info("Saved profile: \(profile.name, privacy: .public)")
        }
    }

    func deleteProfile(_ profileId: UUID) throws {
        try queue.sync {
            var profiles = (try? loadProfilesUnsafe()) ?? []
            profiles.removeAll { $0.id == profileId }
            try writeProfiles(profiles)
            logger.info("Deleted profile: \(profileId.uuidString, privacy: .public)")
        }
    }

    func updateProfile(_ profile: ServerProfile) throws {
        try queue.sync {
            var profiles = (try? loadProfilesUnsafe()) ?? []
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index] = profile
                try writeProfiles(profiles)
                logger.info("Updated profile: \(profile.name, privacy: .public)")
            }
        }
    }

    // MARK: - Internal (not thread-safe, called within queue.sync)

    private func loadProfilesUnsafe() throws -> [ServerProfile] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([ServerProfile].self, from: data)
    }

    private func writeProfiles(_ profiles: [ServerProfile]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profiles)
        try data.write(to: fileURL, options: .atomic)
    }
}
