import AVFoundation
import Foundation
import Speech

enum VoiceRecognitionConfiguration {
    static let locale = Locale(identifier: "en-US")
    static let bufferSize: AVAudioFrameCount = 1_024
    static let finalResultTimeout: Duration = .seconds(10)
}

enum VoiceListenerError: LocalizedError {
    case microphonePermission
    case speechPermission
    case onDeviceUnavailable
    case noSpeech

    var errorDescription: String? {
        switch self {
        case .microphonePermission: "Allow Microphone access from Porter's Setup window."
        case .speechPermission: "Allow Speech Recognition from Porter's Setup window."
        case .onDeviceUnavailable: "On-device English speech recognition is unavailable on this Mac."
        case .noSpeech: "Porter did not hear a command."
        }
    }
}

struct VoiceTranscriptBuffer {
    private(set) var latest: String?

    mutating func accept(_ transcript: String?) {
        guard let transcript, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        latest = transcript
    }
}

@MainActor final class VoiceListener {
    var onTranscript: (String) -> Void = { _ in }
    var onError: (String) -> Void = { NSLog("Porter voice: %@", $0) }
    var onListeningChanged: (Bool) -> Void = { _ in }
    private let engine = AVAudioEngine()
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var timeout: Task<Void, Never>?
    private var listening = false
    private var starting = false
    private var transcripts = VoiceTranscriptBuffer()
    private let cues = VoiceCues()

    func start() {
        guard !starting, !listening, task == nil else { return }
        starting = true
        guard cues.playStart(then: { [weak self] played in self?.startAfterCue(played: played) }) else {
            starting = false
            onError("Could not play the listening-on sound.")
            return
        }
    }

    private func startAfterCue(played: Bool) {
        guard starting else { return }
        starting = false
        guard played else { onError("Could not finish the listening-on sound."); return }
        do { try begin() }
        catch { onError("Could not start voice command: \(error.localizedDescription)") }
    }

    private func begin() throws {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { throw VoiceListenerError.microphonePermission }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else { throw VoiceListenerError.speechPermission }
        guard let recognizer = SFSpeechRecognizer(locale: VoiceRecognitionConfiguration.locale),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else { throw VoiceListenerError.onDeviceUnavailable }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: VoiceRecognitionConfiguration.bufferSize, format: input.outputFormat(forBus: 0)) {
            buffer, _ in request.append(buffer)
        }
        self.request = request
        let callback: @Sendable (SFSpeechRecognitionResult?, (any Error)?) -> Void = { [weak self] result, error in
            let transcript = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true
            Task { @MainActor in
                self?.receive(transcript: transcript, isFinal: isFinal, error: error)
            }
        }
        task = recognizer.recognitionTask(with: request, resultHandler: callback)
        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            cancel()
            throw error
        }
        listening = true
        onListeningChanged(true)
    }

    private func receive(transcript: String?, isFinal: Bool, error: (any Error)?) {
        guard task != nil else { return }
        transcripts.accept(transcript)
        if let error { finish(.failure(error)) }
        else if isFinal { finish(transcripts.latest.map(Result.success) ?? .failure(VoiceListenerError.noSpeech)) }
    }

    func stop() {
        if starting {
            starting = false
            cues.cancelStart()
            return
        }
        guard listening else { return }
        stopMicrophone()
        request?.endAudio()
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: VoiceRecognitionConfiguration.finalResultTimeout) }
            catch is CancellationError { return }
            catch { self?.finish(.failure(error)); return }
            self?.finish(.failure(VoiceListenerError.noSpeech))
        }
    }

    func cancel() {
        starting = false
        cues.cancelStart()
        stopMicrophone()
        timeout?.cancel()
        timeout = nil
        task?.cancel()
        task = nil
        request = nil
        transcripts = VoiceTranscriptBuffer()
    }

    private func stopMicrophone() {
        guard listening else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        listening = false
        onListeningChanged(false)
        if !cues.playStop() { onError("Could not play the listening-off sound.") }
    }

    private func finish(_ result: Result<String, any Error>) {
        guard task != nil else { return }
        let transcript = transcripts.latest
        let wasListening = listening
        cancel()
        switch result {
        case .success(let transcript): onTranscript(transcript)
        case .failure(let error):
            if !wasListening, let transcript { onTranscript(transcript) }
            else { onError("Could not recognize voice command: \(error.localizedDescription)") }
        }
    }
}
