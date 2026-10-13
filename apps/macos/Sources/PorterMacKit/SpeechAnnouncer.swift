import ConversationCore
import Foundation
import PorterPanelModel

@MainActor public final class SpeechAnnouncer: Announcing {
    public var onSpeakingChanged: (Bool) -> Void = { _ in }
    public var onError: (String) -> Void = { NSLog("Porter speech: %@", $0) }
    private let synthesizer: any SpeechSynthesizing
    private let settings: VoiceSettings
    private var queue: [PendingSpeech] = []
    private var active: UUID?
    private var paneVisible = false
    private var locked = false
    private var listening = false

    public init(synthesizer: any SpeechSynthesizing = SystemSpeechSynthesizer(), settings: VoiceSettings) {
        self.synthesizer = synthesizer
        self.settings = settings
        synthesizer.onFinished = { [weak self] id in self?.finished(id) }
    }

    public func announce(_ batch: CompletionBatch) {
        enqueue(.completions(batch.completions, batch.kind))
    }

    public func announceWaiting(_ item: PanelItem) {
        enqueue(.waiting(id: item.id, title: item.title, project: item.projectName))
    }

    public func preview() {
        guard !locked, !listening else { return }
        cancel()
        speak(SpeechTemplates.previewText)
    }

    public func respond(_ text: String) {
        guard !locked, !listening else { return }
        cancel()
        speak(text)
    }

    public func cancel() {
        queue.removeAll()
        active = nil
        synthesizer.cancel()
        onSpeakingChanged(false)
    }

    public func setPaneVisible(_ visible: Bool) {
        paneVisible = visible
        if quiet { cancel() }
    }

    public func setLocked(_ value: Bool) {
        locked = value
        if quiet { cancel() }
    }

    public func setListening(_ value: Bool) {
        listening = value
        if quiet { cancel() }
    }

    public func refreshPolicy() {
        if !settings.speakAnnouncements || quiet { cancel() }
    }

    private var quiet: Bool {
        listening || (paneVisible && settings.quietWhilePaneOpen) || (locked && settings.quietWhileLocked)
    }

    private func enqueue(_ entry: PendingSpeech) {
        guard settings.speakAnnouncements, !quiet else { cancel(); return }
        guard let entry = entry.newerThanQueued(queue) else { return }
        queue = queue.compactMap { $0.removing(entry.itemIds) }
        queue.append(entry)
        drain()
    }

    private func drain() {
        guard active == nil, !queue.isEmpty else { return }
        guard settings.speakAnnouncements, !quiet else { cancel(); return }
        let entry = queue.removeFirst()
        if let text = entry.text() { speak(text) }
    }

    private func speak(_ text: String) {
        let request = SpeechRequest(text: text, voiceIdentifier: settings.voiceIdentifier, rate: settings.speechRate)
        active = request.id
        do {
            try synthesizer.speak(request)
            onSpeakingChanged(true)
        } catch {
            active = nil
            queue.removeAll()
            onSpeakingChanged(false)
            onError("Could not speak Porter announcement: \(error.localizedDescription)")
        }
    }

    private func finished(_ id: UUID) {
        guard active == id else { return }
        active = nil
        onSpeakingChanged(false)
        drain()
    }
}

private enum PendingSpeech {
    case completions([Completion], TurnEndKind)
    case waiting(id: String, title: String, project: String?)

    var itemIds: Set<String> {
        switch self {
        case .completions(let events, _): Set(events.map(\.id))
        case .waiting(let id, _, _): [id]
        }
    }

    func removing(_ ids: Set<String>) -> PendingSpeech? {
        switch self {
        case .completions(let events, let kind):
            let remaining = events.filter { !ids.contains($0.id) }
            return remaining.isEmpty ? nil : .completions(remaining, kind)
        case .waiting(let id, _, _): return ids.contains(id) ? nil : self
        }
    }

    private var completionEvents: [Completion] {
        if case .completions(let events, _) = self { return events }
        return []
    }

    func newerThanQueued(_ queue: [PendingSpeech]) -> PendingSpeech? {
        guard case .completions(let events, let kind) = self else { return self }
        let queued = queue.flatMap(\.completionEvents)
        let current = events.filter { event in
            !queued.contains { $0.id == event.id && $0.end.at > event.end.at }
        }
        return current.isEmpty ? nil : .completions(current, kind)
    }

    func text() -> String? {
        switch self {
        case .completions(let events, let kind): SpeechTemplates.text(for: events, kind: kind)
        case .waiting(_, let title, let project): SpeechTemplates.waiting(title: title, projectName: project)
        }
    }
}
