import SwiftUI

private enum SessionSheet: Identifiable {
    case snippets
    case resources
    case claudeMD
    case hostKeyAlert(HostKeyAlertState)

    var id: String {
        switch self {
        case .snippets: return "snippets"
        case .resources: return "resources"
        case .claudeMD: return "claudeMD"
        case let .hostKeyAlert(s): return "hostKey-\(s.id)"
        }
    }
}

struct SessionView: View {
    @ObservedObject var viewModel: SessionViewModel
    @ObservedObject private var connectionManager: SSHConnectionManager
    let config: AppConfiguration
    @StateObject private var speechService: SpeechRecognitionService
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeSheet: SessionSheet?

    init(viewModel: SessionViewModel, config: AppConfiguration) {
        self.viewModel = viewModel
        connectionManager = viewModel.connectionManager
        self.config = config
        let manager = viewModel.connectionManager
        _speechService = StateObject(wrappedValue: SpeechRecognitionService(
            logger: LoggerFactory.logger(category: "Speech"),
            onTranscriptFinalized: { transcript in
                let textBytes = Array(transcript.utf8)
                manager.sendToRemote(textBytes[...])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let enter: [UInt8] = [0x0D]
                    manager.sendToRemote(enter[...])
                }
            }
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    TerminalContainerView(
                        connectionManager: viewModel.connectionManager,
                        config: config
                    )

                    statusBar
                        .padding(.bottom, geometry.safeAreaInsets.bottom)
                        .background(.ultraThinMaterial)
                }
                .ignoresSafeArea(.container, edges: .bottom)

                if isConnected {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Spacer()
                            microphoneOverlay
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 40)
                        .padding(.trailing, 16)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(viewModel.profile.name)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text(viewModel.settings.host)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { activeSheet = .snippets } label: {
                    Image(systemName: "text.insert")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { activeSheet = .resources } label: {
                    Image(systemName: "terminal")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { activeSheet = .claudeMD } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
            }
        }
        .onAppear {
            viewModel.connect()
        }
        .onDisappear {
            viewModel.disconnect()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                handleForegroundResume()
            }
        }
        .onChange(of: connectionManager.connectionState) { _, newState in
            if case .connected = newState {
                viewModel.discoverResourcesIfNeeded()
            }
        }
        .onChange(of: viewModel.hostKeyAlert) { _, alert in
            if let alert {
                activeSheet = .hostKeyAlert(alert)
            } else if case .hostKeyAlert = activeSheet {
                activeSheet = nil
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case let .hostKeyAlert(alertState):
                HostKeyAlertView(
                    alertState: alertState,
                    onAccept: {
                        activeSheet = nil
                        viewModel.acceptHostKey()
                    },
                    onReject: {
                        activeSheet = nil
                        viewModel.rejectHostKey()
                    }
                )
            case .snippets:
                SnippetDrawerView(
                    config: config,
                    onSnippetSelected: { snippet in
                        activeSheet = nil
                        viewModel.sendSnippet(snippet.command)
                    }
                )
                .presentationDetents([.medium, .large])
            case .resources:
                ClaudeResourcesSidebarView(
                    resources: viewModel.claudeResources,
                    isLoading: viewModel.isDiscoveringResources,
                    onExecute: { command in
                        activeSheet = nil
                        viewModel.sendSnippet(command)
                    },
                    onRefresh: {
                        viewModel.refreshResources()
                    }
                )
            case .claudeMD:
                ClaudeMDDashboardView(
                    settings: viewModel.settings,
                    profile: viewModel.profile,
                    keychainService: viewModel.keychainServiceRef,
                    hostKeyStore: viewModel.hostKeyStoreRef,
                    onCompact: {
                        activeSheet = nil
                        viewModel.sendSnippet("/compact")
                    }
                )
            }
        }
    }

    private func handleForegroundResume() {
        switch connectionManager.connectionState {
        case .disconnected, .failed:
            viewModel.reconnect()
        default:
            break
        }
    }

    private var microphoneOverlay: some View {
        VStack(spacing: 8) {
            if speechService.isListening && !speechService.currentTranscript.isEmpty {
                Text(speechService.currentTranscript)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: 280)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: { speechService.toggleListening() }) {
                Image(systemName: speechService.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(speechService.isListening ? Color.red : Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            }
        }
    }

    private var statusBar: some View {
        VStack(spacing: 0) {
            // DEBUG: full error on a second line when failed
            if case let .failed(msg) = connectionManager.connectionState {
                Text("ERR: \(msg)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.85))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                if isConnected {
                    Button("Disconnect") {
                        viewModel.disconnect()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }

                if case .failed = connectionManager.connectionState {
                    Button("Retry") {
                        viewModel.connect()
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        } // end outer VStack
    }

    private var isConnected: Bool {
        if case .connected = connectionManager.connectionState {
            return true
        }
        return false
    }

    private var statusColor: Color {
        switch connectionManager.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .reconnecting: return .orange
        case .failed: return .red
        }
    }

    private var statusText: String {
        switch connectionManager.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case let .reconnecting(attempt, max): return "Reconnecting (\(attempt)/\(max))..."
        case let .failed(error): return "Failed: \(error)"
        }
    }
}
