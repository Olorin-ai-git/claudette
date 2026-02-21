import Foundation
import os

protocol HostKeyStoreProtocol: Sendable {
    func knownHost(forIdentifier identifier: String) -> KnownHost?
    func storeHost(_ host: KnownHost) throws
    func removeHost(forIdentifier identifier: String) throws
    func allKnownHosts() -> [KnownHost]
}

final class HostKeyStore: HostKeyStoreProtocol, @unchecked Sendable {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.olorin.claudette.hostkeystore")
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("com.olorin.claudette", isDirectory: true)

        if !FileManager.default.fileExists(atPath: appDirectory.path) {
            try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        }

        fileURL = appDirectory.appendingPathComponent("known_hosts.json")
        let path = fileURL.path
        logger.info("Known hosts store path: \(path, privacy: .public)")
    }

    func knownHost(forIdentifier identifier: String) -> KnownHost? {
        queue.sync {
            let hosts = loadHostsUnsafe()
            return hosts.first { $0.hostIdentifier == identifier }
        }
    }

    func storeHost(_ host: KnownHost) throws {
        try queue.sync {
            var hosts = loadHostsUnsafe()
            hosts.removeAll { $0.hostIdentifier == host.hostIdentifier }
            hosts.append(host)
            try writeHosts(hosts)
            logger.info("Stored host key for: \(host.hostIdentifier, privacy: .public)")
        }
    }

    func removeHost(forIdentifier identifier: String) throws {
        try queue.sync {
            var hosts = loadHostsUnsafe()
            hosts.removeAll { $0.hostIdentifier == identifier }
            try writeHosts(hosts)
            logger.info("Removed host key for: \(identifier, privacy: .public)")
        }
    }

    func allKnownHosts() -> [KnownHost] {
        queue.sync {
            loadHostsUnsafe()
        }
    }

    // MARK: - Internal

    private func loadHostsUnsafe() -> [KnownHost] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        guard let data = try? Data(contentsOf: fileURL),
              let hosts = try? JSONDecoder().decode([KnownHost].self, from: data)
        else {
            return []
        }
        return hosts
    }

    private func writeHosts(_ hosts: [KnownHost]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(hosts)
        try data.write(to: fileURL, options: .atomic)
    }
}
