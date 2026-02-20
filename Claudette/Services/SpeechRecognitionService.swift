import AVFoundation
import os
import Speech

@MainActor
final class SpeechRecognitionService: ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var currentTranscript = ""

    private let logger: Logger
    private let onTranscriptFinalized: (String) -> Void

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    init(logger: Logger, onTranscriptFinalized: @escaping (String) -> Void) {
        self.logger = logger
        self.onTranscriptFinalized = onTranscriptFinalized
    }

    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func startListening() {
        guard !isListening else { return }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.beginRecognition()
                default:
                    self.logger.error("Speech recognition not authorized: \(String(describing: status))")
                }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil

        let transcript = currentTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !transcript.isEmpty {
            logger.info("Finalizing transcript: \(transcript.prefix(50), privacy: .public)...")
            onTranscriptFinalized(transcript)
        }

        currentTranscript = ""
        isListening = false
        logger.info("Speech recognition stopped")

        deactivateAudioSession()
    }

    private func beginRecognition() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            logger.error("Speech recognizer not available")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let engine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        self.currentTranscript = result.bestTranscription.formattedString
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        if self.isListening {
                            self.stopListening()
                        }
                    }
                }
            }

            let inputNode = engine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            engine.prepare()
            try engine.start()

            audioEngine = engine
            recognitionRequest = request
            isListening = true
            currentTranscript = ""

            logger.info("Speech recognition started")
        } catch {
            logger.error("Failed to start speech recognition: \(error.localizedDescription)")
            deactivateAudioSession()
        }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
