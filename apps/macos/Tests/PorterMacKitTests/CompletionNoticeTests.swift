import ConversationCore
import Foundation
import PorterPanelModel
import PorterStore
import Synchronization
import Testing
@testable import PorterMacKit

private final class NoticeClock: Sendable {
    private let value = Mutex(Date(timeIntervalSince1970: 1_791_450_000))
    func now() -> Date { value.withLock { $0 } }
    func advance(_ seconds: TimeInterval) { value.withLock { $0 = $0.addingTimeInterval(seconds) } }
}

@MainActor private final class RecordingAnnouncer: Announcing {
    var batches: [CompletionBatch] = []
    func announce(_ batch: CompletionBatch) { batches.append(batch) }
}

@MainActor
@Suite("Completion notice integration")
struct CompletionNoticeTests {
    private func status(_ row: DestinationRow, at now: Date, working: Bool, end: TurnEnd? = nil) -> DestinationStatus {
        let observation = StatusObservation(id: UUID(), destinationId: row.destinationId, activity: working ? .working : .idle,
            attention: .none, evidenceKind: .providerEvent, observedAt: now, receivedAt: now,
            expiresAt: now.addingTimeInterval(60), sequence: 1, connectionEpoch: "test", adapterVersion: "1")
        return DestinationStatus(display: working ? .working : .idle, freshness: .fresh, reachability: .connected,
            lastKnown: observation, turnEnd: end)
    }

    @Test func unfilteredInventoryAndFlushOpenTheExactChat() async throws {
        let row = Harness.row("a", title: "Fix login")
        let source = ScriptedSource(rows: [row], connectors: [Harness.connector])
        let store = try PreferenceStore(path: PreferenceStore.inMemoryPath, deviceId: UUID())
        let clock = NoticeClock()
        let model = AppModel(source: source, store: store, performer: RecordingPerformer(), clock: { clock.now() })
        let domain = "porter.notice-test.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain); model.completionTimer?.cancel() }
        let settings = VoiceSettings(defaults: defaults)
        settings.completedNotices = true
        let announcer = RecordingAnnouncer()
        model.voiceSettings = settings
        model.completionAnnouncer = announcer
        source.statusMap[row.destinationId] = status(row, at: clock.now(), working: true)
        await model.refresh()
        model.query = "no visible matches"
        clock.advance(1)
        source.statusMap[row.destinationId] = status(row, at: clock.now(), working: false, end: TurnEnd(at: clock.now(), kind: .completed))
        await model.refresh()
        #expect(announcer.batches.isEmpty)
        clock.advance(CompletionCoalescer.defaultWindow)
        model.flushCompletions()
        let batch = try #require(announcer.batches.first)
        #expect(batch.completions.map(\.title) == ["Fix login"])
        await model.openCompletion(ids: batch.completions.map(\.id))
        #expect(source.activations.first?.0 == row.destinationId)
    }

    @Test func settingsDefaultOffAndPersistWithoutRequestingPermission() throws {
        let domain = "porter.voice-settings-test.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let initial = VoiceSettings(defaults: defaults)
        #expect(!initial.completedNotices && !initial.speakAnnouncements)
        #expect(initial.quietWhileLocked && initial.quietWhilePaneOpen && initial.waitingNotices)
        initial.completedNotices = true
        initial.speakAnnouncements = true
        initial.voiceCommands = true
        let loaded = VoiceSettings(defaults: defaults)
        #expect(loaded.completedNotices && loaded.speakAnnouncements && loaded.voiceCommands)
    }
}
