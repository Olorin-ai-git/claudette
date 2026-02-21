import SwiftUI

/// Navigation value that carries everything SessionView needs.
/// Using a single Hashable value avoids the `@State selectedProfile` race
/// where `selectedProfile` could be nil when the destination first renders.
private struct SessionDestination: Hashable {
    let settings: ConnectionSettings
    let profile: ServerProfile
}

struct ContentView: View {
    let config: AppConfiguration
    let keychainService: KeychainServiceProtocol
    let profileStore: ProfileStoreProtocol
    let hostKeyStore: HostKeyStoreProtocol
    let sshKeyService: SSHKeyServiceProtocol
    @ObservedObject var connectionManager: SSHConnectionManager
    @ObservedObject var bonjourService: BonjourDiscoveryService

    @StateObject private var profileListViewModel: ProfileListViewModel
    @State private var navigationPath = NavigationPath()
    @State private var showingProfileEditor = false
    @State private var editingProfile: ServerProfile?
    @State private var showingFileBrowser = false
    @State private var showingPathInput = false
    @State private var pendingProfile: ServerProfile?
    @State private var manualPath: String = ""
    /// Owned here so it survives navigationDestination re-evaluations that would otherwise
    /// release the SessionViewModel mid-connection and nil-out the TOFUHostKeyValidator delegate.
    @State private var activeSessionViewModel: SessionViewModel?
    /// Set alongside activeSessionViewModel; onChange fires after @State is
    /// committed, guaranteeing the destination closure sees the viewModel.
    @State private var pendingDestination: SessionDestination?

    init(
        config: AppConfiguration,
        keychainService: KeychainServiceProtocol,
        profileStore: ProfileStoreProtocol,
        hostKeyStore: HostKeyStoreProtocol,
        sshKeyService: SSHKeyServiceProtocol,
        connectionManager: SSHConnectionManager,
        bonjourService: BonjourDiscoveryService
    ) {
        self.config = config
        self.keychainService = keychainService
        self.profileStore = profileStore
        self.hostKeyStore = hostKeyStore
        self.sshKeyService = sshKeyService
        self.connectionManager = connectionManager
        self.bonjourService = bonjourService

        _profileListViewModel = StateObject(wrappedValue: ProfileListViewModel(
            profileStore: profileStore,
            logger: LoggerFactory.logger(category: "ProfileList")
        ))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ProfileListView(
                viewModel: profileListViewModel,
                onSelectProfile: { profile in
                    if let savedPath = profile.lastProjectPath, !savedPath.isEmpty {
                        handleFolderSelected(profile: profile, path: savedPath)
                    } else {
                        pendingProfile = profile
                        manualPath = ""
                        showingPathInput = true
                    }
                },
                onEditProfile: { profile in
                    editingProfile = profile
                    showingProfileEditor = true
                }
            )
            .navigationDestination(for: SessionDestination.self) { _ in
                if let viewModel = activeSessionViewModel {
                    SessionView(viewModel: viewModel, config: config)
                }
            }
        }
        .sheet(isPresented: $showingProfileEditor, onDismiss: {
            editingProfile = nil
            profileListViewModel.loadProfiles()
        }) {
            ProfileEditorView(
                viewModel: ProfileEditorViewModel(
                    profile: editingProfile,
                    profileStore: profileStore,
                    keychainService: keychainService,
                    sshKeyService: sshKeyService,
                    bonjourService: bonjourService,
                    config: config,
                    logger: LoggerFactory.logger(category: "ProfileEditor")
                ),
                onSave: { _ in
                    showingProfileEditor = false
                },
                onCancel: {
                    showingProfileEditor = false
                }
            )
        }
        .alert("Project Path", isPresented: $showingPathInput) {
            TextField("/Users/username/project", text: $manualPath)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Connect") {
                if let profile = pendingProfile, !manualPath.isEmpty {
                    handleFolderSelected(profile: profile, path: manualPath)
                }
            }
            Button("Browse Server...", role: nil) {
                showingFileBrowser = true
            }
            Button("Cancel", role: .cancel) {
                pendingProfile = nil
            }
        } message: {
            Text("Enter the absolute path to your project folder, or browse the server.")
        }
        .fullScreenCover(isPresented: $showingFileBrowser, onDismiss: {}) {
            if let profile = pendingProfile {
                FileBrowserWrapper(
                    profile: profile,
                    keychainService: keychainService,
                    hostKeyStore: hostKeyStore,
                    onSelectFolder: { path in
                        showingFileBrowser = false
                        handleFolderSelected(profile: profile, path: path)
                    },
                    onCancel: {
                        showingFileBrowser = false
                        pendingProfile = nil
                    }
                )
            }
        }
        .onChange(of: pendingDestination) { _, destination in
            if let destination {
                pendingDestination = nil
                navigationPath.append(destination)
            }
        }
    }

    private func handleFolderSelected(profile: ServerProfile, path: String) {
        var updatedProfile = profile
        updatedProfile.lastProjectPath = path
        updatedProfile.lastConnectedAt = Date()
        try? profileStore.updateProfile(updatedProfile)

        let settings = updatedProfile.toConnectionSettings(projectPath: path)

        let hostKeyValidator = TOFUHostKeyValidator(
            hostKeyStore: hostKeyStore,
            logger: LoggerFactory.logger(category: "HostKeyValidator")
        )
        let viewModel = SessionViewModel(
            settings: settings,
            profile: updatedProfile,
            connectionManager: connectionManager,
            keychainService: keychainService,
            hostKeyStore: hostKeyStore,
            hostKeyValidator: hostKeyValidator,
            logger: LoggerFactory.logger(category: "Session")
        )
        // Store in @State so it outlives navigationDestination re-evaluations.
        // Setting both in the same transaction ensures onChange sees both committed.
        activeSessionViewModel = viewModel
        pendingDestination = SessionDestination(settings: settings, profile: updatedProfile)
    }
}

private struct FileBrowserWrapper: View {
    let profile: ServerProfile
    let keychainService: KeychainServiceProtocol
    let hostKeyStore: HostKeyStoreProtocol
    let onSelectFolder: (String) -> Void
    let onCancel: () -> Void

    @StateObject private var viewModel: RemoteFileBrowserViewModel

    init(
        profile: ServerProfile,
        keychainService: KeychainServiceProtocol,
        hostKeyStore: HostKeyStoreProtocol,
        onSelectFolder: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.profile = profile
        self.keychainService = keychainService
        self.hostKeyStore = hostKeyStore
        self.onSelectFolder = onSelectFolder
        self.onCancel = onCancel

        let hostKeyValidator = TOFUHostKeyValidator(
            hostKeyStore: hostKeyStore,
            logger: LoggerFactory.logger(category: "HostKeyValidator")
        )

        _viewModel = StateObject(wrappedValue: RemoteFileBrowserViewModel(
            profile: profile,
            fileBrowserService: RemoteFileBrowserService(
                logger: LoggerFactory.logger(category: "FileBrowser")
            ),
            keychainService: keychainService,
            hostKeyValidator: hostKeyValidator,
            logger: LoggerFactory.logger(category: "FileBrowserVM")
        ))
    }

    var body: some View {
        RemoteFileBrowserView(
            viewModel: viewModel,
            onSelectFolder: onSelectFolder,
            onCancel: onCancel
        )
    }
}
