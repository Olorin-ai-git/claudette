import Citadel
import Foundation
import NIOSSH
import os

@MainActor
final class RemoteFileBrowserService: ObservableObject {
    @Published private(set) var isConnected: Bool = false

    private let logger: Logger
    private var client: SSHClient?
    private var sftpClient: SFTPClient?

    init(logger: Logger) {
        self.logger = logger
    }

    func connect(
        host: String,
        port: Int,
        username _: String,
        authMethod: SSHAuthenticationMethod,
        hostKeyValidator: SSHHostKeyValidator
    ) async throws {
        let config = AppConfiguration()

        let sshClient = try await SSHClient.connect(
            host: host,
            port: port,
            authenticationMethod: authMethod,
            hostKeyValidator: hostKeyValidator,
            reconnect: .never,
            connectTimeout: .seconds(Int64(config.sshConnectTimeout))
        )

        client = sshClient
        sftpClient = try await sshClient.openSFTP()
        isConnected = true

        logger.info("SFTP connected to \(host, privacy: .public):\(port)")
    }

    func listDirectory(atPath path: String) async throws -> [RemoteFileEntry] {
        guard let sftp = sftpClient else {
            throw RemoteFileBrowserError.notConnected
        }

        let nameMessages = try await sftp.listDirectory(atPath: path)
        var entries: [RemoteFileEntry] = []

        for nameMsg in nameMessages {
            for component in nameMsg.components {
                let name = component.filename
                if name == "." || name == ".." {
                    continue
                }

                let fullPath: String
                if path.hasSuffix("/") {
                    fullPath = path + name
                } else {
                    fullPath = path + "/" + name
                }

                let isDirectory = component.attributes.permissions
                    .map { $0 & 0o40000 != 0 } ?? false

                let size = component.attributes.size
                let modifiedAt = component.attributes.accessModificationTime?.modificationTime

                entries.append(RemoteFileEntry(
                    name: name,
                    path: fullPath,
                    isDirectory: isDirectory,
                    size: size,
                    modifiedAt: modifiedAt
                ))
            }
        }

        // Sort: directories first, then alphabetical
        entries.sort { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return entries
    }

    func getHomeDirectory(username: String) async throws -> String {
        guard let sftp = sftpClient else {
            throw RemoteFileBrowserError.notConnected
        }

        // Try to resolve ~ via realpath
        do {
            let attributes = try await sftp.getAttributes(at: "/Users/" + username)
            if attributes.permissions.map({ $0 & 0o40000 != 0 }) ?? false {
                return "/Users/" + username
            }
        } catch {
            // Fallback: try /home/username
        }

        do {
            let attributes = try await sftp.getAttributes(at: "/home/" + username)
            if attributes.permissions.map({ $0 & 0o40000 != 0 }) ?? false {
                return "/home/" + username
            }
        } catch {
            // Final fallback
        }

        return "/"
    }

    func disconnect() {
        Task {
            try? await client?.close()
        }
        client = nil
        sftpClient = nil
        isConnected = false
        logger.info("SFTP disconnected")
    }
}

enum RemoteFileBrowserError: LocalizedError {
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to remote server"
        }
    }
}
