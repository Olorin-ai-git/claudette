import Foundation

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
    }

    private static func requiredDict(_ dict: [String: Any], key: String) -> [String: Any] {
        guard let value = dict[key] as? [String: Any] else {
            fatalError("Missing required configuration section: \(key)")
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
