import Foundation

struct KeyboardButtonConfig: Sendable {
    let label: String
    let byteSequence: [UInt8]
    let action: String?
}

struct AppConfiguration: Sendable {
    let sshDefaultPort: Int
    let sshConnectTimeout: Int
    let sshCommand: String

    let bonjourServiceType: String
    let bonjourDomain: String

    let terminalFontName: String
    let terminalFontSize: CGFloat
    let terminalForegroundColor: String
    let terminalBackgroundColor: String
    let terminalCaretColor: String
    let terminalTermType: String
    let terminalDefaultColumns: Int
    let terminalDefaultRows: Int

    let splashAccentColor: String
    let splashAccentColorLight: String
    let splashAccentColorDark: String
    let splashBackgroundColor: String
    let splashAppName: String
    let splashCursorSymbol: String
    let splashSlogan: String
    let splashFooterText: String

    let keychainServiceName: String
    let loggerSubsystem: String

    // Keyboard Accessory
    let keyboardAccessoryHeight: CGFloat
    let keyboardAccessoryBackgroundColor: String
    let keyboardAccessoryButtonColor: String
    let keyboardAccessoryButtonTextColor: String
    let keyboardAccessoryButtons: [KeyboardButtonConfig]

    // Session Persistence (tmux)
    let tmuxEnabled: Bool
    let tmuxSessionPrefix: String
    let reconnectMaxAttempts: Int
    let reconnectDelaySeconds: Double

    // Network Probe
    let networkProbeIntervalSeconds: Double
    let networkProbeTimeoutSeconds: Double
    let networkProbeDegradedThresholdMs: Double

    // File Editor
    let fileEditorMaxSizeBytes: Int
    let fileEditorFontName: String
    let fileEditorFontSize: CGFloat

    /// Snippets
    let snippetsStorageFileName: String

    init() {
        guard let url = Bundle.main.url(forResource: "Configuration", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            fatalError("Failed to load Configuration.plist")
        }

        let ssh = Self.requiredDict(root, key: "SSH")
        let bonjour = Self.requiredDict(root, key: "Bonjour")
        let terminal = Self.requiredDict(root, key: "Terminal")
        let keychain = Self.requiredDict(root, key: "Keychain")
        let loggerConfig = Self.requiredDict(root, key: "Logger")

        sshDefaultPort = Self.required(ssh, key: "DefaultPort")
        sshConnectTimeout = Self.required(ssh, key: "ConnectTimeoutSeconds")
        sshCommand = Self.required(ssh, key: "Command")

        bonjourServiceType = Self.required(bonjour, key: "ServiceType")
        bonjourDomain = Self.required(bonjour, key: "Domain")

        terminalFontName = Self.required(terminal, key: "FontName")
        terminalFontSize = CGFloat(Self.required(terminal, key: "FontSize") as Double)
        terminalForegroundColor = Self.required(terminal, key: "ForegroundColor")
        terminalBackgroundColor = Self.required(terminal, key: "BackgroundColor")
        terminalCaretColor = Self.required(terminal, key: "CaretColor")
        terminalTermType = Self.required(terminal, key: "TermType")
        terminalDefaultColumns = Self.required(terminal, key: "DefaultColumns")
        terminalDefaultRows = Self.required(terminal, key: "DefaultRows")

        let splash = Self.requiredDict(root, key: "Splash")
        splashAccentColor = Self.required(splash, key: "AccentColor")
        splashAccentColorLight = Self.required(splash, key: "AccentColorLight")
        splashAccentColorDark = Self.required(splash, key: "AccentColorDark")
        splashBackgroundColor = Self.required(splash, key: "BackgroundColor")
        splashAppName = Self.required(splash, key: "AppName")
        splashCursorSymbol = Self.required(splash, key: "CursorSymbol")
        splashSlogan = Self.required(splash, key: "Slogan")
        splashFooterText = Self.required(splash, key: "FooterText")

        keychainServiceName = Self.required(keychain, key: "ServiceName")
        loggerSubsystem = Self.required(loggerConfig, key: "Subsystem")

        // Keyboard Accessory
        let keyboard = Self.requiredDict(root, key: "KeyboardAccessory")
        keyboardAccessoryHeight = CGFloat(Self.required(keyboard, key: "Height") as Double)
        keyboardAccessoryBackgroundColor = Self.required(keyboard, key: "BackgroundColor")
        keyboardAccessoryButtonColor = Self.required(keyboard, key: "ButtonColor")
        keyboardAccessoryButtonTextColor = Self.required(keyboard, key: "ButtonTextColor")

        let buttonArray: [Any] = Self.requiredArray(keyboard, key: "Buttons")
        keyboardAccessoryButtons = buttonArray.compactMap { element -> KeyboardButtonConfig? in
            guard let dict = element as? [String: Any] else { return nil }
            guard let label = dict["Label"] as? String else { return nil }
            let action = dict["Action"] as? String
            var bytes: [UInt8] = []
            if let rawBytes = dict["ByteSequence"] as? [Any] {
                bytes = rawBytes.compactMap { v in
                    if let i = v as? Int { return UInt8(i) }
                    if let i = v as? NSNumber { return UInt8(i.intValue) }
                    return nil
                }
            }
            return KeyboardButtonConfig(label: label, byteSequence: bytes, action: action)
        }

        // Session Persistence
        let session = Self.requiredDict(root, key: "SessionPersistence")
        tmuxEnabled = session["TmuxEnabled"] as? Bool ?? false
        tmuxSessionPrefix = Self.required(session, key: "TmuxSessionPrefix")
        reconnectMaxAttempts = Self.required(session, key: "ReconnectMaxAttempts")
        reconnectDelaySeconds = Self.required(session, key: "ReconnectDelaySeconds")

        // Network Probe
        let probe = Self.requiredDict(root, key: "NetworkProbe")
        networkProbeIntervalSeconds = Self.required(probe, key: "IntervalSeconds")
        networkProbeTimeoutSeconds = Self.required(probe, key: "TimeoutSeconds")
        networkProbeDegradedThresholdMs = Self.required(probe, key: "DegradedThresholdMs")

        // File Editor
        let editor = Self.requiredDict(root, key: "FileEditor")
        fileEditorMaxSizeBytes = Self.required(editor, key: "MaxFileSizeBytes")
        fileEditorFontName = Self.required(editor, key: "FontName")
        fileEditorFontSize = CGFloat(Self.required(editor, key: "FontSize") as Double)

        // Snippets
        let snippets = Self.requiredDict(root, key: "Snippets")
        snippetsStorageFileName = Self.required(snippets, key: "StorageFileName")
    }

    private static func requiredDict(_ dict: [String: Any], key: String) -> [String: Any] {
        guard let value = dict[key] as? [String: Any] else {
            fatalError("Missing required configuration section: \(key)")
        }
        return value
    }

    private static func requiredArray(_ dict: [String: Any], key: String) -> [Any] {
        guard let value = dict[key] as? [Any] else {
            fatalError("Missing required configuration array: \(key)")
        }
        return value
    }

    private static func required<T>(_ dict: [String: Any], key: String) -> T {
        guard let value = dict[key] as? T else {
            fatalError("Missing or invalid configuration value: \(key)")
        }
        return value
    }
}
