import SwiftUI
import SwiftTerm
import os

struct TerminalContainerView: UIViewRepresentable {
    let connectionManager: SSHConnectionManager
    let config: AppConfiguration

    func makeUIView(context: Context) -> TerminalView {
        let font = UIFont(name: config.terminalFontName, size: config.terminalFontSize)
            ?? UIFont.monospacedSystemFont(ofSize: config.terminalFontSize, weight: .regular)

        let terminalView = TerminalView(frame: .zero, font: font)
        terminalView.terminalDelegate = context.coordinator
        terminalView.nativeForegroundColor = UIColor(hex: config.terminalForegroundColor)
        terminalView.nativeBackgroundColor = UIColor(hex: config.terminalBackgroundColor)
        terminalView.caretColor = UIColor(hex: config.terminalCaretColor)
        terminalView.optionAsMetaKey = true

        connectionManager.setTerminalView(terminalView)

        return terminalView
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {}

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

        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            connectionManager.sendToRemote(data)
        }

        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            logger.debug("Terminal resized to \(newCols)x\(newRows)")
            connectionManager.resizeTerminal(cols: newCols, rows: newRows)
        }

        func setTerminalTitle(source: TerminalView, title: String) {}

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        func scrolled(source: TerminalView, position: Double) {}

        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            guard let url = URL(string: link) else { return }
            UIApplication.shared.open(url)
        }

        func bell(source: TerminalView) {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }

        func clipboardCopy(source: TerminalView, content: Data) {
            if let string = String(data: content, encoding: .utf8) {
                UIPasteboard.general.string = string
            }
        }

        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
