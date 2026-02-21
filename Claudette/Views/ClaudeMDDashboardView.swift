import Citadel
import CryptoKit
import Foundation
import NIOSSH
import os
import SwiftUI

struct ClaudeMDDashboardView: View {
    let settings: ConnectionSettings
    let profile: ServerProfile
    let keychainService: KeychainServiceProtocol
    let hostKeyStore: HostKeyStoreProtocol
    let onCompact: () -> Void

    @StateObject private var viewModel: ClaudeMDDashboardViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        settings: ConnectionSettings,
        profile: ServerProfile,
        keychainService: KeychainServiceProtocol,
        hostKeyStore: HostKeyStoreProtocol,
        onCompact: @escaping () -> Void
    ) {
        self.settings = settings
        self.profile = profile
        self.keychainService = keychainService
        self.hostKeyStore = hostKeyStore
        self.onCompact = onCompact
        _viewModel = StateObject(wrappedValue: ClaudeMDDashboardViewModel(
            settings: settings,
            profile: profile,
            keychainService: keychainService,
            hostKeyStore: hostKeyStore,
            logger: LoggerFactory.logger(category: "ClaudeMD")
        ))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading CLAUDE.md...")
                } else if let error = viewModel.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task { await viewModel.loadClaudeMD() }
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        tokenGauge
                        TextEditor(text: $viewModel.content)
                            .font(.system(.body, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: viewModel.content) { _, _ in
                                viewModel.updateTokenEstimate()
                            }
                    }
                }
            }
            .navigationTitle("CLAUDE.md")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        onCompact()
                    } label: {
                        Label("Compact", systemImage: "arrow.down.right.and.arrow.up.left")
                    }

                    Button {
                        Task { await viewModel.saveClaudeMD() }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
                }
            }
            .task {
                await viewModel.loadClaudeMD()
            }
        }
    }

    private var tokenGauge: some View {
        HStack {
            Image(systemName: "gauge.medium")
                .foregroundStyle(.secondary)

            Text("\(viewModel.estimatedTokens) tokens (est.)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(viewModel.content.count) chars")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }
}

@MainActor
final class ClaudeMDDashboardViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var error: String?
    @Published var hasUnsavedChanges: Bool = false
    @Published var estimatedTokens: Int = 0

    private let settings: ConnectionSettings
    private let profile: ServerProfile
    private let keychainService: KeychainServiceProtocol
    private let hostKeyStore: HostKeyStoreProtocol
    private let logger: Logger
    private var fileBrowserService: RemoteFileBrowserService?
    private var originalContent: String = ""
    private var claudeMDPath: String = ""

    init(
        settings: ConnectionSettings,
        profile: ServerProfile,
        keychainService: KeychainServiceProtocol,
        hostKeyStore: HostKeyStoreProtocol,
        logger: Logger
    ) {
        self.settings = settings
        self.profile = profile
        self.keychainService = keychainService
        self.hostKeyStore = hostKeyStore
        self.logger = logger
    }

    func loadClaudeMD() async {
        isLoading = true
        error = nil

        do {
            let service = RemoteFileBrowserService(
                logger: LoggerFactory.logger(category: "ClaudeMDBrowser")
            )

            let authMethod: SSHAuthenticationMethod
            switch profile.authMethod {
            case .password:
                let password = keychainService.retrievePassword(profileId: profile.id) ?? ""
                authMethod = .passwordBased(username: profile.username, password: password)
            case let .generatedKey(keyTag), let .importedKey(keyTag):
                guard let keyData = keychainService.retrievePrivateKeyData(keyTag: keyTag) else {
                    error = "SSH key not found"
                    isLoading = false
                    return
                }
                let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
                authMethod = .ed25519(username: profile.username, privateKey: privateKey)
            }

            let validator = TOFUHostKeyValidator(
                hostKeyStore: hostKeyStore,
                logger: LoggerFactory.logger(category: "HostKeyValidator")
            )

            try await service.connect(
                host: settings.host,
                port: settings.port,
                username: settings.username,
                authMethod: authMethod,
                hostKeyValidator: validator.makeValidator(host: settings.host, port: settings.port)
            )

            fileBrowserService = service

            // Try project CLAUDE.md first, then home
            let projectClaudeMD = settings.projectPath + "/CLAUDE.md"
            if await service.fileExists(atPath: projectClaudeMD) {
                claudeMDPath = projectClaudeMD
            } else {
                claudeMDPath = projectClaudeMD
                content = ""
                originalContent = ""
                isLoading = false
                updateTokenEstimate()
                return
            }

            let data = try await service.readFile(atPath: claudeMDPath)
            if let text = String(data: data, encoding: .utf8) {
                content = text
                originalContent = text
                updateTokenEstimate()
            }

            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func saveClaudeMD() async {
        guard let service = fileBrowserService else { return }
        isSaving = true
        error = nil

        do {
            guard let data = content.data(using: .utf8) else {
                error = "Failed to encode content"
                isSaving = false
                return
            }

            try await service.writeFile(data: data, atPath: claudeMDPath)
            originalContent = content
            hasUnsavedChanges = false
            isSaving = false
        } catch {
            self.error = error.localizedDescription
            isSaving = false
        }
    }

    func updateTokenEstimate() {
        // Rough estimation: ~4 chars per token for English text
        let charCount = content.count
        estimatedTokens = max(charCount / 4, 0)
        hasUnsavedChanges = content != originalContent
    }
}
