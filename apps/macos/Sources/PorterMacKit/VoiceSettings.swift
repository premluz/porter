import AVFoundation
import Foundation
import Observation

/// Preferences contain presentation choices only; no audio, transcripts, or conversation metadata.
@MainActor
@Observable
public final class VoiceSettings {
    private let defaults: UserDefaults
    private enum Key {
        static let waiting = "porter.voice.waitingNotices"
        static let completed = "porter.voice.completedNotices"
        static let speech = "porter.voice.speakAnnouncements"
        static let voice = "porter.voice.voiceIdentifier"
        static let rate = "porter.voice.speechRate"
        static let pane = "porter.voice.quietWhilePaneOpen"
        static let lock = "porter.voice.quietWhileLocked"
        static let commands = "porter.voice.commands"
    }

    public var waitingNotices: Bool { didSet { defaults.set(waitingNotices, forKey: Key.waiting) } }
    public var completedNotices: Bool { didSet { defaults.set(completedNotices, forKey: Key.completed) } }
    public var speakAnnouncements: Bool { didSet { defaults.set(speakAnnouncements, forKey: Key.speech) } }
    public var voiceIdentifier: String { didSet { defaults.set(voiceIdentifier, forKey: Key.voice) } }
    public var speechRate: Float { didSet { defaults.set(speechRate, forKey: Key.rate) } }
    public var quietWhilePaneOpen: Bool { didSet { defaults.set(quietWhilePaneOpen, forKey: Key.pane) } }
    public var quietWhileLocked: Bool { didSet { defaults.set(quietWhileLocked, forKey: Key.lock) } }
    public var voiceCommands: Bool { didSet { defaults.set(voiceCommands, forKey: Key.commands) } }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        waitingNotices = defaults.object(forKey: Key.waiting) as? Bool ?? true
        completedNotices = defaults.bool(forKey: Key.completed)
        speakAnnouncements = defaults.bool(forKey: Key.speech)
        voiceIdentifier = defaults.string(forKey: Key.voice) ?? ""
        let stored = (defaults.object(forKey: Key.rate) as? NSNumber)?.floatValue ?? AVSpeechUtteranceDefaultSpeechRate
        speechRate = stored.isFinite ? min(max(stored, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate) : AVSpeechUtteranceDefaultSpeechRate
        quietWhilePaneOpen = defaults.object(forKey: Key.pane) as? Bool ?? true
        quietWhileLocked = defaults.object(forKey: Key.lock) as? Bool ?? true
        voiceCommands = defaults.bool(forKey: Key.commands)
    }
}
