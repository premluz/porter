import AVFoundation
import Foundation

public struct SpeechRequest: Sendable, Equatable {
    public let id: UUID
    public let text: String
    public let voiceIdentifier: String
    public let rate: Float

    public init(id: UUID = UUID(), text: String, voiceIdentifier: String, rate: Float) {
        self.id = id
        self.text = text
        self.voiceIdentifier = voiceIdentifier
        self.rate = rate
    }
}

@MainActor public protocol SpeechSynthesizing: AnyObject {
    var onFinished: ((UUID) -> Void)? { get set }
    func speak(_ request: SpeechRequest) throws
    func cancel()
}

public enum SpeechSynthesisError: Error, LocalizedError {
    case voiceUnavailable(String)
    case invalidRate

    public var errorDescription: String? {
        switch self {
        case .voiceUnavailable(let identifier): "The selected system voice is unavailable: \(identifier)"
        case .invalidRate: "The selected speech rate is outside the system's supported range"
        }
    }
}

@MainActor public final class SystemSpeechSynthesizer: NSObject, SpeechSynthesizing, AVSpeechSynthesizerDelegate {
    public var onFinished: ((UUID) -> Void)?
    private let engine = AVSpeechSynthesizer()
    private var active: (request: UUID, utterance: ObjectIdentifier)?

    public override init() {
        super.init()
        engine.delegate = self
    }

    public func speak(_ request: SpeechRequest) throws {
        precondition(active == nil, "System speech requests must not overlap")
        guard request.rate.isFinite, (AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate).contains(request.rate) else {
            throw SpeechSynthesisError.invalidRate
        }
        let utterance = AVSpeechUtterance(string: request.text)
        if !request.voiceIdentifier.isEmpty {
            guard let voice = AVSpeechSynthesisVoice(identifier: request.voiceIdentifier) else {
                throw SpeechSynthesisError.voiceUnavailable(request.voiceIdentifier)
            }
            utterance.voice = voice
        }
        utterance.rate = request.rate
        active = (request.id, ObjectIdentifier(utterance))
        engine.speak(utterance)
    }

    public func cancel() {
        active = nil
        if engine.isSpeaking, !engine.stopSpeaking(at: .immediate) {
            NSLog("Porter speech: the system synthesizer could not stop active speech")
        }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finished(ObjectIdentifier(utterance))
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finished(ObjectIdentifier(utterance))
    }

    private nonisolated func finished(_ utterance: ObjectIdentifier) {
        Task { @MainActor [weak self] in
            guard let self, let active = self.active, active.utterance == utterance else { return }
            self.active = nil
            self.onFinished?(active.request)
        }
    }
}
