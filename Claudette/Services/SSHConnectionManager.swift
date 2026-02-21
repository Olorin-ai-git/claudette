import Citadel
import CryptoKit
import Foundation
import NIOCore
import NIOSSH
import os
import SwiftTerm

final class SSHConnectionManager: ObservableObject {
    @Published private(set) var connectionState: ConnectionState = .disconnected

    typealias OutputInterceptor = @Sendable ([UInt8]) -> Void
    var outputInterceptor: OutputInterceptor?

    private let config: AppConfiguration
    private let keychainService: KeychainServiceProtocol
    private let tmuxService: TmuxSessionServiceProtocol
    private let logger: Logger
    private var stdinWriter: TTYStdinWriter?
    private var connectionTask: Task<Void, Never>?
    private weak var terminalView: ClaudetteTerminalView?

    private var lastSettings: ConnectionSettings?
    private var lastCredential: String?
    private var lastHostKeyValidator: SSHHostKeyValidator?
    private var lastProfileId: UUID?

    init(config: AppConfiguration, keychainService: KeychainServiceProtocol, logger: Logger) {
        self.config = config
        self.keychainService = keychainService
        tmuxService = TmuxSessionService()
        self.logger = logger
    }

    func setTerminalView(_ view: ClaudetteTerminalView) {
        terminalView = view
    }

    func connect(
        settings: ConnectionSettings,
        credential: String,
        hostKeyValidator: SSHHostKeyValidator,
        profileId: UUID? = nil
    ) {
        switch connectionState {
        case .connecting, .connected, .reconnecting:
            return
        case .disconnected, .failed:
            break
        }

        guard !credential.isEmpty || settings.authMethod.isKeyBased else {
            connectionState = .failed(errorDescription: "Missing credential")
            return
        }

        lastSettings = settings
        lastCredential = credential
        lastHostKeyValidator = hostKeyValidator
        lastProfileId = profileId

        connectionState = .connecting
        logger.info("Connecting to \(settings.host, privacy: .public):\(settings.port)")

        let config = self.config
        let logger = self.logger
        let keychainService = self.keychainService
        let tmuxService = self.tmuxService
        let sessionName: String? = (config.tmuxEnabled && profileId != nil)
            ? tmuxService.sessionName(profileId: profileId!, prefix: config.tmuxSessionPrefix)
            : nil

        connectionTask = Task { [weak self] in
            do {
                fputs("[Claudette] buildAuthMethod start\n", stderr)
                let sshAuth = try Self.buildAuthMethod(
                    settings: settings,
                    credential: credential,
                    keychainService: keychainService
                )
                fputs("[Claudette] SSHClient.connect → \(settings.host):\(settings.port)\n", stderr)

                let client = try await SSHClient.connect(
                    host: settings.host,
                    port: settings.port,
                    authenticationMethod: sshAuth,
                    hostKeyValidator: hostKeyValidator,
                    reconnect: .never,
                    connectTimeout: .seconds(Int64(config.sshConnectTimeout))
                )
                fputs("[Claudette] SSH connected OK\n", stderr)

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

                fputs("[Claudette] opening PTY \(initialCols)x\(initialRows)\n", stderr)
                try await client.withPTY(ptyRequest) { [weak self] inbound, outbound in
                    guard let self else { return }
                    fputs("[Claudette] PTY opened\n", stderr)

                    await MainActor.run { [weak self] in
                        self?.stdinWriter = outbound
                    }

                    let command: String
                    if let name = sessionName {
                        command = tmuxService.attachOrCreateCommand(
                            sessionName: name,
                            directory: settings.projectPath,
                            initialCommand: config.sshCommand
                        ) + "\n"
                    } else {
                        command = "cd " + settings.projectPath + " && " + config.sshCommand + "\n"
                    }

                    fputs("[Claudette] sending command: \(command.prefix(120))\n", stderr)
                    var cmdBuffer = ByteBufferAllocator().buffer(capacity: command.utf8.count)
                    cmdBuffer.writeString(command)
                    try await outbound.write(cmdBuffer)
                    fputs("[Claudette] command sent, reading output\n", stderr)

                    logger.info("PTY established, sent command via tmux: \(sessionName ?? "direct", privacy: .public)")

                    let interceptor = await MainActor.run { [weak self] in
                        self?.outputInterceptor
                    }

                    for try await chunk in inbound {
                        let bytes: [UInt8]
                        switch chunk {
                        case let .stdout(buffer):
                            bytes = Array(buffer.readableBytesView)
                        case let .stderr(buffer):
                            bytes = Array(buffer.readableBytesView)
                        }

                        interceptor?(bytes)

                        await MainActor.run { [weak self] in
                            self?.terminalView?.appendOutputForBlockDetection(bytes)
                            self?.terminalView?.feed(byteArray: bytes[...])
                        }
                    }
                }

                fputs("[Claudette] PTY session ended\n", stderr)
                logger.info("PTY session ended")
                await MainActor.run { [weak self] in
                    self?.connectionState = .disconnected
                    self?.stdinWriter = nil
                }

            } catch is CancellationError {
                fputs("[Claudette] connection cancelled\n", stderr)
                logger.info("Connection cancelled")
                await MainActor.run { [weak self] in
                    self?.connectionState = .disconnected
                    self?.stdinWriter = nil
                }
            } catch {
                let message = Self.humanReadableError(error)
                fputs("[Claudette] CONNECTION FAILED: \(message) | raw: \(error)\n", stderr)
                logger.error("Connection failed: \(message)")
                await MainActor.run { [weak self] in
                    self?.connectionState = .failed(errorDescription: message)
                    self?.stdinWriter = nil
                }
            }
        }
    }

    func reconnect() {
        guard let settings = lastSettings,
              let credential = lastCredential,
              let validator = lastHostKeyValidator
        else {
            logger.warning("Cannot reconnect — no previous connection parameters")
            return
        }

        let maxAttempts = config.reconnectMaxAttempts
        let delay = config.reconnectDelaySeconds

        connectionTask?.cancel()
        connectionTask = nil
        stdinWriter = nil

        connectionTask = Task { [weak self] in
            for attempt in 1 ... maxAttempts {
                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    self?.connectionState = .reconnecting(attempt: attempt, maxAttempts: maxAttempts)
                }

                self?.logger.info("Reconnect attempt \(attempt)/\(maxAttempts)")

                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                guard !Task.isCancelled else { return }

                await MainActor.run { [weak self] in
                    self?.connectionState = .disconnected
                }

                await MainActor.run { [weak self] in
                    self?.connect(
                        settings: settings,
                        credential: credential,
                        hostKeyValidator: validator,
                        profileId: self?.lastProfileId
                    )
                }

                // Wait briefly then check if we connected
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                let state = await MainActor.run { [weak self] in
                    self?.connectionState
                }

                if case .connected = state {
                    self?.logger.info("Reconnected successfully on attempt \(attempt)")
                    return
                }
            }

            await MainActor.run { [weak self] in
                self?.connectionState = .failed(errorDescription: "Reconnection failed after \(maxAttempts) attempts")
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
        credential: String,
        keychainService: KeychainServiceProtocol
    ) throws -> SSHAuthenticationMethod {
        switch settings.authMethod {
        case .password:
            return .passwordBased(username: settings.username, password: credential)

        case let .generatedKey(keyTag), let .importedKey(keyTag):
            guard let keyData = keychainService.retrievePrivateKeyData(keyTag: keyTag) else {
                throw SSHKeyAuthError.keyNotFound
            }

            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
            return .ed25519(username: settings.username, privateKey: privateKey)
        }
    }
}

enum SSHKeyAuthError: LocalizedError {
    case keyNotFound

    var errorDescription: String? {
        switch self {
        case .keyNotFound:
            return "SSH key not found in Keychain — try regenerating"
        }
    }
}
