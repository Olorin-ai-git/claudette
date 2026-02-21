import SwiftTerm
import UIKit

final class ClaudetteTerminalView: TerminalView {
    private var accessoryView: ExtendedKeyboardAccessoryView?
    private var doubleTapGesture: UITapGestureRecognizer?

    /// Rolling buffer of recent terminal output lines for block detection.
    private var outputLines: [String] = []
    private var lineBuffer: String = ""

    func configureAccessoryView(config: AppConfiguration, onKeyTapped: @escaping (ArraySlice<UInt8>) -> Void) {
        let view = ExtendedKeyboardAccessoryView(
            config: config,
            onKeyTapped: onKeyTapped,
            onDismissKeyboard: { [weak self] in
                self?.resignFirstResponder()
            }
        )
        accessoryView = view
        inputAccessoryView = view
    }

    /// SwiftTerm's setupOptions() (called from didMoveToWindow) resets inputAccessoryView
    /// to its own TerminalAccessory. Override didMoveToWindow to re-apply ours afterward.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let view = accessoryView {
            inputAccessoryView = view
        }
    }

    func configureBlockSelect() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        gesture.numberOfTapsRequired = 2
        addGestureRecognizer(gesture)
        doubleTapGesture = gesture
    }

    /// Feed raw bytes into the line buffer for block detection.
    func appendOutputForBlockDetection(_ bytes: [UInt8]) {
        guard let text = String(bytes: bytes, encoding: .utf8) else { return }
        lineBuffer += text
        while let nlIndex = lineBuffer.firstIndex(of: "\n") {
            let line = String(lineBuffer[lineBuffer.startIndex ..< nlIndex])
            lineBuffer = String(lineBuffer[lineBuffer.index(after: nlIndex)...])
            outputLines.append(line)
            // Keep last 500 lines
            if outputLines.count > 500 {
                outputLines.removeFirst(outputLines.count - 500)
            }
        }
    }

    // MARK: - Block Select

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .recognized, !outputLines.isEmpty else { return }

        let location = gesture.location(in: self)
        let terminal = getTerminal()
        let fontSize: CGFloat = 11
        let lineHeight = fontSize * 1.5
        let tappedRow = Int(location.y / lineHeight) + terminal.getTopVisibleRow()

        // Map screen row to outputLines index (approximate)
        let lineIndex = min(max(tappedRow, 0), outputLines.count - 1)

        guard let block = TerminalBlockDetector.detectBlock(lines: outputLines, atLine: lineIndex) else {
            return
        }

        UIPasteboard.general.string = block.content

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        showCopyToast()
    }

    private func showCopyToast() {
        let toast = UILabel()
        toast.text = "Block copied"
        toast.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        toast.textColor = .white
        toast.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 8
        toast.clipsToBounds = true
        toast.alpha = 0

        addSubview(toast)
        toast.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: centerXAnchor),
            toast.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            toast.widthAnchor.constraint(equalToConstant: 120),
            toast.heightAnchor.constraint(equalToConstant: 28),
        ])

        UIView.animate(withDuration: 0.2) {
            toast.alpha = 1
        }

        UIView.animate(withDuration: 0.3, delay: 1.0, options: []) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }

    // MARK: - External Keyboard (iPad) Key Commands

    override var keyCommands: [UIKeyCommand]? {
        var commands: [UIKeyCommand] = []

        // Ctrl+C (interrupt)
        commands.append(
            UIKeyCommand(
                title: "Interrupt",
                action: #selector(sendCtrlC),
                input: "c",
                modifierFlags: .control
            )
        )

        // Ctrl+T (new task in Claude Code)
        commands.append(
            UIKeyCommand(
                title: "New Task",
                action: #selector(sendCtrlT),
                input: "t",
                modifierFlags: .control
            )
        )

        // Ctrl+D (EOF)
        commands.append(
            UIKeyCommand(
                title: "EOF",
                action: #selector(sendCtrlD),
                input: "d",
                modifierFlags: .control
            )
        )

        // Ctrl+Z (suspend)
        commands.append(
            UIKeyCommand(
                title: "Suspend",
                action: #selector(sendCtrlZ),
                input: "z",
                modifierFlags: .control
            )
        )

        // Ctrl+L (clear)
        commands.append(
            UIKeyCommand(
                title: "Clear Screen",
                action: #selector(sendCtrlL),
                input: "l",
                modifierFlags: .control
            )
        )

        // Ctrl+A (beginning of line)
        commands.append(
            UIKeyCommand(
                title: "Beginning of Line",
                action: #selector(sendCtrlA),
                input: "a",
                modifierFlags: .control
            )
        )

        // Ctrl+E (end of line)
        commands.append(
            UIKeyCommand(
                title: "End of Line",
                action: #selector(sendCtrlE),
                input: "e",
                modifierFlags: .control
            )
        )

        return commands
    }

    @objc private func sendCtrlC() {
        sendBytes([0x03])
    }

    @objc private func sendCtrlT() {
        sendBytes([0x14])
    }

    @objc private func sendCtrlD() {
        sendBytes([0x04])
    }

    @objc private func sendCtrlZ() {
        sendBytes([0x1A])
    }

    @objc private func sendCtrlL() {
        sendBytes([0x0C])
    }

    @objc private func sendCtrlA() {
        sendBytes([0x01])
    }

    @objc private func sendCtrlE() {
        sendBytes([0x05])
    }

    private func sendBytes(_ bytes: [UInt8]) {
        terminalDelegate?.send(source: self, data: bytes[...])
    }
}
