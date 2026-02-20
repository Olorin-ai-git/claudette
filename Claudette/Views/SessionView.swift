import SwiftUI

struct SessionView: View {
    @ObservedObject var viewModel: SessionViewModel
    let config: AppConfiguration
    @StateObject private var speechService: SpeechRecognitionService

    init(viewModel: SessionViewModel, config: AppConfiguration) {
        self.viewModel = viewModel
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
                        microphoneOverlay
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 40)
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isConnected)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.settings.host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            viewModel.connect()
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

            if case .failed = viewModel.connectionManager.connectionState {
                Button("Retry") {
                    viewModel.connect()
                }
                .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var isConnected: Bool {
        if case .connected = viewModel.connectionManager.connectionState {
            return true
        }
        return false
    }

    private var statusColor: Color {
        switch viewModel.connectionManager.connectionState {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .failed: return .red
        }
    }

    private var statusText: String {
        switch viewModel.connectionManager.connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case let .failed(error): return "Failed: \(error)"
        }
    }
}
