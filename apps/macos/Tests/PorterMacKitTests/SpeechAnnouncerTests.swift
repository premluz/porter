import AVFoundation
import ConversationCore
import Foundation
import PorterPanelModel
import Testing
@testable import PorterMacKit

@Suite("Metadata-only system speech") @MainActor
struct SpeechAnnouncerTests {
    @Test("templates clean and truncate title/project, with distinct interrupted and grouped wording")
    func templates() {
        let long = String(repeating: "a", count: SpeechTemplates.titleLimit + 10)
        #expect(SpeechTemplates.clean("  Fix 🚀 <login>\n", limit: SpeechTemplates.titleLimit) == "Fix login")
        #expect(SpeechTemplates.clean("Réparer Café №2 / .NET", limit: SpeechTemplates.titleLimit) == "Réparer Café 2 NET")
        #expect(SpeechTemplates.clean(long, limit: SpeechTemplates.titleLimit).count == SpeechTemplates.titleLimit)
        #expect(SpeechTemplates.text(for: batch([event("a", title: "Fix 🚀 login", project: "Atlas!")]))
                == "Task completed: Fix login")
        #expect(SpeechTemplates.text(for: batch([event("a")])) == "Task completed: Fix login")
        #expect(SpeechTemplates.text(for: batch([event("a", provider: "claude-code")]))
                == "Claude has completed a task")
        #expect(SpeechTemplates.text(for: batch([event("a", provider: "chatgpt")]))
                == "Chat GPT has completed a task")
        #expect(SpeechTemplates.text(for: batch([event("a", provider: "codex"), event("b", provider: "chatgpt")]))
                == "Chat GPT has completed 2 tasks")
        #expect(SpeechTemplates.text(for: batch([event("a", provider: "claude"), event("b", provider: "chatgpt")]))
                == "2 tasks completed")
        #expect(SpeechTemplates.text(for: batch([event("a", project: nil)])) == "Task completed: Fix login")
        #expect(SpeechTemplates.text(for: batch([event("a", kind: .interrupted)])) == "Fix login was interrupted")
        #expect(SpeechTemplates.text(for: batch([event("a"), event("b")])) == "2 tasks completed")
        #expect(SpeechTemplates.text(for: batch([event("a", kind: .interrupted), event("b", kind: .interrupted)]))
                == "2 tasks were interrupted")
    }

    @Test("queue never overlaps and only newest queued metadata for the same identity is spoken")
    func queue() {
        let (speaker, fake, settings) = makeSpeaker()
        settings.voiceIdentifier = "selected-voice"
        settings.speechRate = AVSpeechUtteranceDefaultSpeechRate
        speaker.announce(batch([event("busy")]))
        speaker.announce(batch([event("a", title: "Old title"), event("b", title: "Other task")]))
        speaker.announce(batch([event("a", title: "Newest title")]))
        speaker.announce(batch([event("a", title: "Older signal", offset: -1)]))
        #expect(fake.requests.count == 1)
        #expect(fake.requests.first?.voiceIdentifier == "selected-voice")
        #expect(fake.requests.first?.rate == settings.speechRate)
        fake.finish()
        #expect(fake.requests.last?.text == "Task completed: Other task")
        fake.finish()
        #expect(fake.requests.last?.text == "Task completed: Newest title")
        fake.finish()
        #expect(!fake.overlapped)
    }

    @Test("quiet conditions stop active speech, discard queued events and suppress later events")
    func quietPolicies() {
        for condition in ["pane", "locked", "listening"] {
            let (speaker, fake, _) = makeSpeaker()
            speaker.announce(batch([event("a")]))
            speaker.announce(batch([event("b")]))
            if condition == "pane" { speaker.setPaneVisible(true) }
            if condition == "locked" { speaker.setLocked(true) }
            if condition == "listening" { speaker.setListening(true) }
            speaker.announce(batch([event("c")]))
            #expect(fake.requests.count == 1 && fake.active == nil)
            speaker.setPaneVisible(false)
            speaker.setLocked(false)
            speaker.setListening(false)
            #expect(fake.requests.count == 1)
        }
    }

    @Test("quiet preferences are optional; listening suppression always applies")
    func optOutQuiet() {
        let (speaker, fake, settings) = makeSpeaker()
        settings.quietWhilePaneOpen = false
        settings.quietWhileLocked = false
        speaker.setPaneVisible(true)
        speaker.setLocked(true)
        speaker.announce(batch([event("a")]))
        #expect(fake.requests.count == 1)
        speaker.setListening(true)
        speaker.announce(batch([event("b")]))
        #expect(fake.requests.count == 1 && fake.active == nil)
    }

    @Test("speech is off by default; explicit preview works in Setup but never while locked or listening")
    func preview() {
        let (speaker, fake, settings) = makeSpeaker(enabled: false)
        #expect(!settings.speakAnnouncements)
        speaker.announce(batch([event("a")]))
        #expect(fake.requests.isEmpty)
        speaker.setPaneVisible(true)
        speaker.preview()
        #expect(fake.requests.map(\.text) == [SpeechTemplates.previewText])
        speaker.setLocked(true)
        speaker.preview()
        speaker.setLocked(false)
        speaker.setListening(true)
        speaker.preview()
        #expect(fake.requests.count == 1)
    }

    @Test("disabling speech cancels active work and late finished callbacks cannot affect a new preview")
    func settingChanges() throws {
        let (speaker, fake, settings) = makeSpeaker()
        speaker.announce(batch([event("a")]))
        let canceled = try #require(fake.active)
        settings.speakAnnouncements = false
        speaker.refreshPolicy()
        #expect(fake.active == nil)
        speaker.preview()
        let preview = fake.active
        fake.onFinished?(canceled)
        #expect(fake.active == preview && fake.requests.count == 2)
        speaker.cancel()
        #expect(fake.active == nil)
    }

    @Test("needs-you speech is independent of notice toggle; failures are reported and clear speech state")
    func waitingAndErrors() {
        let (speaker, fake, settings) = makeSpeaker()
        settings.waitingNotices = false
        let row = DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: "a", provider: "codex",
            title: "Fix login", profileAlias: "Atlas", connectorId: "editor", reachability: .connected,
            tabId: 1, windowId: 1, url: nil, routeCount: 1
        )
        let item = PanelBuilder.build(PanelInputs(rows: [row], connectors: [], records: [], now: Date())).navigable[0]
        speaker.announceWaiting(item)
        #expect(fake.requests.last?.text == "Fix login needs you, in Atlas")
        fake.finish()
        var errors: [String] = []
        var speaking: [Bool] = []
        speaker.onError = { errors.append($0) }
        speaker.onSpeakingChanged = { speaking.append($0) }
        fake.shouldFail = true
        speaker.announce(batch([event("b")]))
        #expect(errors.count == 1 && errors.first?.contains("fake voice unavailable") == true)
        #expect(speaking.last == false)
    }

    private func makeSpeaker(enabled: Bool = true) -> (SpeechAnnouncer, FakeSpeechSynthesizer, VoiceSettings) {
        guard let defaults = UserDefaults(suiteName: "porter-speech-test-\(UUID().uuidString)") else {
            preconditionFailure("Could not create isolated speech test defaults")
        }
        let settings = VoiceSettings(defaults: defaults)
        settings.speakAnnouncements = enabled
        let fake = FakeSpeechSynthesizer()
        return (SpeechAnnouncer(synthesizer: fake, settings: settings), fake, settings)
    }

    private func event(
        _ id: String, title: String = "Fix login", project: String? = "Atlas", provider: String = "",
        kind: TurnEndKind = .completed, offset: TimeInterval = 0
    ) -> Completion {
        Completion(id: id, title: title, provider: provider, projectName: project,
                   end: TurnEnd(at: Date(timeIntervalSince1970: 1 + offset), kind: kind))
    }

    private func batch(_ events: [Completion]) -> CompletionBatch {
        let now = Date(timeIntervalSince1970: 2)
        var coalescer = CompletionCoalescer(window: 1)
        _ = coalescer.append(events, now: now)
        return coalescer.flush(now: now.addingTimeInterval(1))[0]
    }
}

@MainActor private final class FakeSpeechSynthesizer: SpeechSynthesizing {
    var onFinished: ((UUID) -> Void)?
    var requests: [SpeechRequest] = []
    var active: UUID?
    var overlapped = false
    var shouldFail = false

    func speak(_ request: SpeechRequest) throws {
        if shouldFail { throw NSError(domain: "fake voice unavailable", code: 1) }
        if active != nil { overlapped = true }
        active = request.id
        requests.append(request)
    }

    func cancel() { active = nil }

    func finish() {
        guard let id = active else { Issue.record("No fake speech request is active"); return }
        active = nil
        onFinished?(id)
    }
}
