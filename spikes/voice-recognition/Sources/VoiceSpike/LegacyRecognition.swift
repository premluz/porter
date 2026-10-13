import Speech

@MainActor
final class LegacyRecognition {
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, any Error>?
    private var timeout: Task<Void, Never>?

    func recognize(audio: URL, locale: Locale) async throws -> String {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SpikeError.invalid("Speech Recognition not authorized; use the bundle's permission button")
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw SpikeError.invalid("SFSpeechRecognizer on-device recognition unavailable")
        }
        let request = SFSpeechURLRecognitionRequest(url: audio)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.task = recognizer.recognitionTask(with: request) { result, error in
                let text = result?.isFinal == true ? result?.bestTranscription.formattedString : nil
                Task { @MainActor in
                    if let error { self.finish(.failure(error)) }
                    else if let text { self.finish(.success(text)) }
                }
            }
            self.timeout = Task {
                do { try await Task.sleep(for: .seconds(SpikeConfiguration.recognitionTimeoutSeconds)) }
                catch is CancellationError { return }
                catch { self.finish(.failure(error)); return }
                self.finish(.failure(SpikeError.invalid("SFSpeechRecognizer recognition timed out")))
            }
        }
    }

    private func finish(_ result: Result<String, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeout?.cancel()
        task?.cancel()
        task = nil
        continuation.resume(with: result)
    }
}
