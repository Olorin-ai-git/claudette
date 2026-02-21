import SwiftUI

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
    @State private var selectedProfile: ServerProfile?
    @State private var manualPath: String = ""

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
                    selectedProfile = profile
                    if let lastPath = profile.lastProjectPath, !lastPath.isEmpty {
                        handleFolderSelected(profile: profile, path: lastPath)
                    } else {
                        manualPath = ""
                        showingPathInput = true
                    }
                },
                onEditProfile: { profile in
                    editingProfile = profile
                    showingProfileEditor = true
                }
            )
            .navigationDestination(for: ConnectionSettings.self) { settings in
                if let profile = selectedProfile {
                    let hostKeyValidator = TOFUHostKeyValidator(
                        hostKeyStore: hostKeyStore,
                        logger: LoggerFactory.logger(category: "HostKeyValidator")
                    )

                    SessionView(
                        viewModel: SessionViewModel(
                            settings: settings,
                            profile: profile,
                            connectionManager: connectionManager,
                            keychainService: keychainService,
                            hostKeyValidator: hostKeyValidator,
                            logger: LoggerFactory.logger(category: "Session")
                        ),
                        config: config
                    )
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
                if let profile = selectedProfile, !manualPath.isEmpty {
                    handleFolderSelected(profile: profile, path: manualPath)
                }
            }
            Button("Browse Server...", role: nil) {
                showingFileBrowser = true
            }
            Button("Cancel", role: .cancel) {
                selectedProfile = nil
            }
        } message: {
            Text("Enter the absolute path to your project folder, or browse the server.")
        }
        .fullScreenCover(isPresented: $showingFileBrowser, onDismiss: {
            // Clean up if user cancelled
        }) {
            if let profile = selectedProfile {
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
                        selectedProfile = nil
                    }
                )
            }
        }
    }

    private func handleFolderSelected(profile: ServerProfile, path: String) {
        // Update profile with last project path and connection time
        var updatedProfile = profile
        updatedProfile.lastProjectPath = path
        updatedProfile.lastConnectedAt = Date()
        try? profileStore.updateProfile(updatedProfile)

        selectedProfile = updatedProfile

        let settings = updatedProfile.toConnectionSettings(projectPath: path)
        navigationPath.append(settings)
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
