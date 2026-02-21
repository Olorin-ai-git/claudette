import Citadel
import CryptoKit
import Foundation
import NIOSSH
import SwiftUI

struct HooksAutomationView: View {
    let settings: ConnectionSettings
    let profile: ServerProfile
    let keychainService: KeychainServiceProtocol
    let hostKeyStore: HostKeyStoreProtocol

    @StateObject private var settingsService: ClaudeSettingsService
    @StateObject private var fileBrowserService: RemoteFileBrowserService
    @Environment(\.dismiss) private var dismiss
    @State private var showingHookEditor = false
    @State private var selectedEventType: String = "PreToolUse"
    @State private var editingHook: ClaudeHook?

    private static let eventTypes = [
        "PreToolUse",
        "PostToolUse",
        "Notification",
        "Stop",
    ]

    init(
        settings: ConnectionSettings,
        profile: ServerProfile,
        keychainService: KeychainServiceProtocol,
        hostKeyStore: HostKeyStoreProtocol
    ) {
        self.settings = settings
        self.profile = profile
        self.keychainService = keychainService
        self.hostKeyStore = hostKeyStore

        let service = RemoteFileBrowserService(
            logger: LoggerFactory.logger(category: "HooksBrowser")
        )
        _fileBrowserService = StateObject(wrappedValue: service)
        _settingsService = StateObject(wrappedValue: ClaudeSettingsService(
            fileBrowserService: service,
            logger: LoggerFactory.logger(category: "HooksSettings")
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if settingsService.isLoading {
                    ProgressView("Loading hooks...")
                } else {
                    hooksList
                }
            }
            .navigationTitle("Hooks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingHook = nil
                        showingHookEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await connectAndLoad()
            }
            .onDisappear {
                fileBrowserService.disconnect()
            }
            .sheet(isPresented: $showingHookEditor) {
                HookEditorFormView(
                    hook: editingHook,
                    eventType: selectedEventType,
                    onSave: { hook, eventType in
                        addOrUpdateHook(hook, eventType: eventType)
                        showingHookEditor = false
                        Task { await settingsService.saveSettings() }
                    },
                    onCancel: {
                        showingHookEditor = false
                    }
                )
            }
        }
    }

    private var hooksList: some View {
        List {
            ForEach(Self.eventTypes, id: \.self) { eventType in
                Section(eventType) {
                    let hooks = settingsService.settings?.hooks?[eventType] ?? []
                    if hooks.isEmpty {
                        Text("No hooks")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(hooks) { hook in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(hook.command)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(2)

                                    if let matcher = hook.matcher, !matcher.isEmpty {
                                        Text("matcher: " + matcher)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(hook.type)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }

                                Spacer()
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    removeHook(hook, fromEvent: eventType)
                                    Task { await settingsService.saveSettings() }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func connectAndLoad() async {
        do {
            let authMethod: SSHAuthenticationMethod
            switch profile.authMethod {
            case .password:
                let password = keychainService.retrievePassword(profileId: profile.id) ?? ""
                authMethod = .passwordBased(username: profile.username, password: password)
            case let .generatedKey(keyTag), let .importedKey(keyTag):
                guard let keyData = keychainService.retrievePrivateKeyData(keyTag: keyTag) else { return }
                let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
                authMethod = .ed25519(username: profile.username, privateKey: privateKey)
            }

            let validator = TOFUHostKeyValidator(
                hostKeyStore: hostKeyStore,
                logger: LoggerFactory.logger(category: "HostKeyValidator")
            )

            try await fileBrowserService.connect(
                host: settings.host,
                port: settings.port,
                username: settings.username,
                authMethod: authMethod,
                hostKeyValidator: validator.makeValidator(host: settings.host, port: settings.port)
            )

            await settingsService.loadSettings()
        } catch {
            settingsService.error = error.localizedDescription
        }
    }

    private func addOrUpdateHook(_ hook: ClaudeHook, eventType: String) {
        if settingsService.settings == nil {
            settingsService.settings = ClaudeSettings()
        }
        if settingsService.settings?.hooks == nil {
            settingsService.settings?.hooks = [:]
        }
        if settingsService.settings?.hooks?[eventType] == nil {
            settingsService.settings?.hooks?[eventType] = []
        }

        if let index = settingsService.settings?.hooks?[eventType]?.firstIndex(where: { $0.id == hook.id }) {
            settingsService.settings?.hooks?[eventType]?[index] = hook
        } else {
            settingsService.settings?.hooks?[eventType]?.append(hook)
        }
    }

    private func removeHook(_ hook: ClaudeHook, fromEvent eventType: String) {
        settingsService.settings?.hooks?[eventType]?.removeAll { $0.id == hook.id }
    }
}
