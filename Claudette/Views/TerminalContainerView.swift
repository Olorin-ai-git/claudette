import os
import SwiftTerm
import SwiftUI

struct TerminalContainerView: UIViewRepresentable {
    let connectionManager: SSHConnectionManager
    let config: AppConfiguration

    func makeUIView(context: Context) -> ClaudetteTerminalView {
        let font = UIFont(name: config.terminalFontName, size: config.terminalFontSize)
            ?? UIFont.monospacedSystemFont(ofSize: config.terminalFontSize, weight: .regular)

        let terminalView = ClaudetteTerminalView(frame: .zero, font: font)
        terminalView.terminalDelegate = context.coordinator
        terminalView.nativeForegroundColor = UIColor(hex: config.terminalForegroundColor)
        terminalView.nativeBackgroundColor = UIColor(hex: config.terminalBackgroundColor)
        terminalView.caretColor = UIColor(hex: config.terminalCaretColor)
        terminalView.optionAsMetaKey = true

        terminalView.configureAccessoryView(config: config, onKeyTapped: { bytes in
            connectionManager.sendToRemote(bytes)
        }, onPaste: {
            Self.handlePaste(connectionManager: connectionManager)
        })
        terminalView.configureBlockSelect()

        connectionManager.setTerminalView(terminalView)

        return terminalView
    }

    func updateUIView(_: ClaudetteTerminalView, context _: Context) {}

    /// Reads UIPasteboard and sends content to the remote SSH session.
    /// Images are uploaded via a side-channel exec and the path is typed.
    /// Text is sent directly as bytes (standard terminal paste).
    private static func handlePaste(connectionManager: SSHConnectionManager) {
        let pasteboard = UIPasteboard.general

        // Prefer image when available (matches Claude Code Ctrl+V behavior)
        if let image = pasteboard.image,
           let jpegData = image.jpegData(compressionQuality: 0.85)
        {
            let filename = "claudette_paste_\(UUID().uuidString.prefix(8)).jpg"
            let remotePath = "/tmp/\(filename)"
            Task {
                do {
                    try await connectionManager.uploadData(jpegData, remotePath: remotePath)
                    let pathBytes = Array(remotePath.utf8)
                    await MainActor.run {
                        connectionManager.sendToRemote(pathBytes[...])
                    }
                } catch {
                    fputs("[Claudette] Image paste failed: \(error)\n", stderr)
                }
            }
            return
        }

        // Fall back to text paste
        if let text = pasteboard.string, !text.isEmpty {
            let bytes = Array(text.utf8)
            connectionManager.sendToRemote(bytes[...])
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            connectionManager: connectionManager,
            logger: LoggerFactory.logger(category: "TerminalView")
        )
    }

    final class Coordinator: NSObject, TerminalViewDelegate {
        private let connectionManager: SSHConnectionManager
        private let logger: Logger

        init(connectionManager: SSHConnectionManager, logger: Logger) {
            self.connectionManager = connectionManager
            self.logger = logger
        }

        func send(source _: TerminalView, data: ArraySlice<UInt8>) {
            connectionManager.sendToRemote(data)
        }

        func sizeChanged(source _: TerminalView, newCols: Int, newRows: Int) {
            logger.debug("Terminal resized to \(newCols)x\(newRows)")
            connectionManager.resizeTerminal(cols: newCols, rows: newRows)
        }

        func setTerminalTitle(source _: TerminalView, title _: String) {}

        func hostCurrentDirectoryUpdate(source _: TerminalView, directory _: String?) {}

        func scrolled(source _: TerminalView, position _: Double) {}

        func requestOpenLink(source _: TerminalView, link: String, params _: [String: String]) {
            guard let url = URL(string: link) else { return }
            UIApplication.shared.open(url)
        }

        func bell(source _: TerminalView) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }

        func clipboardCopy(source _: TerminalView, content: Data) {
            if let string = String(data: content, encoding: .utf8) {
                UIPasteboard.general.string = string
            }
        }

        func iTermContent(source _: TerminalView, content _: ArraySlice<UInt8>) {}

        func rangeChanged(source _: TerminalView, startY _: Int, endY _: Int) {}
    }
}
