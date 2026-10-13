import AVFoundation
import Speech

enum AnalyzerRecognition {
    static func recognize(audio: URL, locale: Locale) async throws -> String {
        guard SpeechTranscriber.isAvailable,
              let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw SpikeError.invalid("SpeechTranscriber unavailable for requested locale")
        }
        let transcriber = SpeechTranscriber(locale: supported, preset: .transcription)
        guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
            throw SpikeError.invalid("SpeechTranscriber assets not installed; no automatic download")
        }
        let file = try AVAudioFile(forReading: audio)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let resultTask = Task {
            var pieces: [String] = []
            for try await result in transcriber.results {
                pieces.append(String(result.text.characters))
            }
            return pieces.joined(separator: " ")
        }
        do {
            try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
            let text = try await resultTask.value
            guard !text.isEmpty else { throw SpikeError.invalid("SpeechTranscriber returned no speech") }
            return text
        } catch {
            await analyzer.cancelAndFinishNow()
            resultTask.cancel()
            throw error
        }
    }
}
