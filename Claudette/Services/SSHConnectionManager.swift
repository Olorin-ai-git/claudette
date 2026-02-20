import Citadel
import Crypto
import Foundation
import NIOCore
import NIOSSH
import os
import SwiftTerm

final class SSHConnectionManager: ObservableObject {
    @Published private(set) var connectionState: ConnectionState = .disconnected

    private let config: AppConfiguration
    private let logger: Logger
    private var stdinWriter: TTYStdinWriter?
    private var connectionTask: Task<Void, Never>?
    private weak var terminalView: TerminalView?

    init(config: AppConfiguration, logger: Logger) {
        self.config = config
        self.logger = logger
    }

    func setTerminalView(_ view: TerminalView) {
        terminalView = view
    }

    func connect(settings: ConnectionSettings, credential: String) {
        switch connectionState {
        case .connecting, .connected:
            return
        case .disconnected, .failed:
            break
        }

        guard !credential.isEmpty else {
            connectionState = .failed(errorDescription: "Missing credential")
            return
        }

        connectionState = .connecting
        logger.info("Connecting to \(settings.host, privacy: .public):\(settings.port)")

        let config = self.config
        let logger = self.logger

        connectionTask = Task { [weak self] in
            do {
                let sshAuth = try Self.buildAuthMethod(
                    settings: settings,
                    credential: credential
                )

                let client = try await SSHClient.connect(
                    host: settings.host,
                    port: settings.port,
                    authenticationMethod: sshAuth,
                    hostKeyValidator: .acceptAnything(),
                    reconnect: .never,
                    connectTimeout: .seconds(Int64(config.sshConnectTimeout))
                )

                await MainActor.run { [weak self] in
                    self?.connectionState = .connected
                }
                logger.info("SSH connected, opening PTY")

                let (initialCols, initialRows) = await MainActor.run { [weak self] () -> (Int, Int) in
                    guard let terminal = self?.terminalView?.getTerminal() else {
                        return (config.terminalDefaultColumns, config.terminalDefaultRows)
                    }
                    return (terminal.cols, terminal.rows)
                }

                let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
                    wantReply: true,
                    term: config.terminalTermType,
                    terminalCharacterWidth: initialCols,
                    terminalRowHeight: initialRows,
                    terminalPixelWidth: 0,
                    terminalPixelHeight: 0,
                    terminalModes: .init([.ECHO: 1])
                )

                try await client.withPTY(ptyRequest) { [weak self] inbound, outbound in
                    guard let self else { return }

                    await MainActor.run { [weak self] in
                        self?.stdinWriter = outbound
                    }

                    let projectPath = config.sshProjectsBasePath + "/" + settings.projectFolder
                    let command = "cd " + projectPath + " && " + config.sshCommand + "\n"
                    var cmdBuffer = ByteBufferAllocator().buffer(capacity: command.utf8.count)
                    cmdBuffer.writeString(command)
                    try await outbound.write(cmdBuffer)

                    logger.info("PTY established, sent command: \(config.sshCommand, privacy: .public)")

                    for try await chunk in inbound {
                        let bytes: [UInt8]
                        switch chunk {
                        case let .stdout(buffer):
                            bytes = Array(buffer.readableBytesView)
                        case let .stderr(buffer):
                            bytes = Array(buffer.readableBytesView)
                        }

                        await MainActor.run { [weak self] in
                            self?.terminalView?.feed(byteArray: bytes[...])
                        }
                    }
                }

                logger.info("PTY session ended")
                await MainActor.run { [weak self] in
                    self?.connectionState = .disconnected
                    self?.stdinWriter = nil
                }

            } catch is CancellationError {
                logger.info("Connection cancelled")
                await MainActor.run { [weak self] in
                    self?.connectionState = .disconnected
                    self?.stdinWriter = nil
                }
            } catch {
                let message = Self.humanReadableError(error)
                logger.error("Connection failed: \(message)")
                await MainActor.run { [weak self] in
                    self?.connectionState = .failed(errorDescription: message)
                    self?.stdinWriter = nil
                }
            }
        }
    }

    func sendToRemote(_ data: ArraySlice<UInt8>) {
        guard let writer = stdinWriter else { return }
        let bytes = Array(data)
        Task {
            var buffer = ByteBufferAllocator().buffer(capacity: bytes.count)
            buffer.writeBytes(bytes)
            try? await writer.write(buffer)
        }
    }

    func resizeTerminal(cols: Int, rows: Int) {
        guard let writer = stdinWriter else { return }
        logger.debug("Resizing terminal to \(cols)x\(rows)")
        Task {
            try? await writer.changeSize(
                cols: cols,
                rows: rows,
                pixelWidth: 0,
                pixelHeight: 0
            )
        }
    }

    func disconnect() {
        logger.info("Disconnecting SSH session")
        connectionTask?.cancel()
        connectionTask = nil
        stdinWriter = nil
        connectionState = .disconnected
    }

    private static func humanReadableError(_ error: Error) -> String {
        if let sshError = error as? SSHClientError {
            switch sshError {
            case .allAuthenticationOptionsFailed:
                return "Authentication failed — check username and password"
            case .unsupportedPasswordAuthentication:
                return "Server does not support password authentication"
            case .unsupportedPrivateKeyAuthentication:
                return "Server does not support private key authentication"
            case .unsupportedHostBasedAuthentication:
                return "Server does not support host-based authentication"
            case .channelCreationFailed:
                return "Failed to create SSH channel"
            }
        }

        if error is AuthenticationFailed {
            return "Authentication failed — check username and password"
        }

        let description = error.localizedDescription
        if description.contains("timed out") || description.contains("timeout") {
            return "Connection timed out — check host and port"
        }
        if description.contains("Connection refused") {
            return "Connection refused — check host and port"
        }

        return description
    }

    private static func buildAuthMethod(
        settings: ConnectionSettings,
        credential: String
    ) throws -> SSHAuthenticationMethod {
        switch settings.authMethod {
        case .password:
            return .passwordBased(username: settings.username, password: credential)
        case .privateKey:
            let privateKey = try Insecure.RSA.PrivateKey(sshRsa: credential)
            return .rsa(username: settings.username, privateKey: privateKey)
        }
    }
}
