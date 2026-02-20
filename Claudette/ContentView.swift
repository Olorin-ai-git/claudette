import SwiftUI

struct ContentView: View {
    let config: AppConfiguration
    let keychainService: KeychainServiceProtocol
    @ObservedObject var connectionManager: SSHConnectionManager
    @ObservedObject var connectionSettingsViewModel: ConnectionSettingsViewModel

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ConnectionSettingsView(
                viewModel: connectionSettingsViewModel,
                onConnect: { settings in
                    navigationPath.append(settings)
                }
            )
            .navigationDestination(for: ConnectionSettings.self) { settings in
                SessionView(
                    viewModel: SessionViewModel(
                        settings: settings,
                        connectionManager: connectionManager,
                        keychainService: keychainService,
                        logger: LoggerFactory.logger(category: "Session")
                    ),
                    config: config
                )
            }
        }
    }
}
