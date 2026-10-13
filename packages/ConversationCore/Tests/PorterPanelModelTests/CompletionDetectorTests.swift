import ConversationCore
import Foundation
import PorterStore
import Testing
@testable import PorterPanelModel

@Suite("Completion requires observed work followed by explicit end evidence")
struct CompletionDetectorTests {
    private let start = Fixture.now

    @Test("launch end markers never announce; observed work ends once with title and project only")
    func observedWork() {
        var detector = CompletionDetector()
        let old = end(-10)
        #expect(detector.update(items: [item("a", end: old)], now: start).isEmpty)
        #expect(detector.update(items: [item("a", display: .working, end: old)], now: start).isEmpty)
        let completed = item("a", end: end(1))
        let events = detector.update(items: [completed], now: start.addingTimeInterval(2))
        #expect(events == [Completion(id: completed.id, title: "Fix login", provider: "codex", projectName: "Atlas", end: end(1))])
        #expect(detector.update(items: [completed], now: start.addingTimeInterval(3)).isEmpty)
        #expect(detector.update(items: [item("b", end: end(3))], now: start.addingTimeInterval(4)).isEmpty)
    }

    @Test("staleness, hidden work, closed routes and removal disarm instead of claiming completion")
    func lapsePaths() {
        let lapses = [item("a", freshness: .stale, end: end(1)), item("a", freshness: .unknown, end: end(1)),
                      item("a", hidden: true), item("a", open: false)]
        for lapse in lapses {
            var detector = CompletionDetector()
            _ = detector.update(items: [item("a", display: .working)], now: start)
            #expect(detector.update(items: [lapse], now: start.addingTimeInterval(1)).isEmpty)
            #expect(detector.update(items: [item("a", end: end(2))], now: start.addingTimeInterval(3)).isEmpty)
        }
        var removed = CompletionDetector()
        _ = removed.update(items: [item("a", display: .working)], now: start)
        #expect(removed.update(items: [], now: start.addingTimeInterval(1)).isEmpty)
        #expect(removed.update(items: [item("a", end: end(2))], now: start.addingTimeInterval(3)).isEmpty)
        var hidden = CompletionDetector()
        _ = hidden.update(items: [item("a", display: .working, hidden: true)], now: start)
        #expect(hidden.update(items: [item("a", end: end(1))], now: start.addingTimeInterval(2)).isEmpty)
    }

    @Test("idle without end evidence, historical late evidence and non-newer ends never announce")
    func noInventedEnd() {
        for candidate in [nil, end(-1), end(0), end(10)] {
            var detector = CompletionDetector()
            _ = detector.update(items: [item("a", display: .working)], now: start)
            #expect(detector.update(items: [item("a", end: candidate)], now: start.addingTimeInterval(1)).isEmpty)
        }
        var detector = CompletionDetector()
        _ = detector.update(items: [item("a", display: .working, end: end(1))], now: start)
        #expect(detector.update(items: [item("a", end: end(1))], now: start.addingTimeInterval(2)).isEmpty)
    }

    @Test("interrupted ends stay distinct and the next observed turn can end while display remains working")
    func repeatedTurns() {
        var detector = CompletionDetector()
        _ = detector.update(items: [item("a", display: .working)], now: start)
        let interrupted = end(1, kind: .interrupted)
        let first = detector.update(items: [item("a", display: .working, end: interrupted)], now: start.addingTimeInterval(2))
        #expect(first.map(\.end.kind) == [.interrupted])
        let second = detector.update(items: [item("a", end: end(3))], now: start.addingTimeInterval(4))
        #expect(second.map(\.end.kind) == [.completed])
    }

    @Test("two different projects sharing a title arm independently by stable identity")
    func independentProjects() {
        var detector = CompletionDetector()
        let work = [item("a", display: .working), item("b", display: .working, project: "Memento")]
        _ = detector.update(items: work, now: start)
        let ends = [item("a", end: end(1)), item("b", end: end(1), project: "Memento")]
        let emitted = detector.update(items: ends, now: start.addingTimeInterval(2))
        #expect(Set(emitted.map(\.id)).count == 2)
        #expect(Set(emitted.compactMap(\.projectName)) == ["Atlas", "Memento"])
    }

    @Test("browser profiles remain independent and do not become spoken project names")
    func browserDataset() {
        var detector = CompletionDetector()
        let work = [item("browser-a", display: .working, project: "Personal", provider: "claude"),
                    item("browser-b", display: .working, project: "Work", provider: "chatgpt")]
        #expect(detector.update(items: work, now: start).isEmpty)
        let ends = [item("browser-a", end: end(1), project: "Personal", provider: "claude"),
                    item("browser-b", end: end(1, kind: .interrupted), project: "Work", provider: "chatgpt")]
        let emitted = detector.update(items: ends, now: start.addingTimeInterval(2))
        #expect(Set(emitted.map(\.id)).count == 2)
        #expect(emitted.allSatisfy { $0.projectName == nil })
        #expect(emitted.map(\.end.kind) == [.completed, .interrupted])
        #expect(emitted.map(\.provider) == ["claude", "chatgpt"])
    }

    private func end(_ seconds: TimeInterval, kind: TurnEndKind = .completed) -> TurnEnd {
        TurnEnd(at: start.addingTimeInterval(seconds), kind: kind)
    }

    private func item(
        _ id: String, display: DisplayStatus = .idle, freshness: Freshness = .fresh, end: TurnEnd? = nil,
        hidden: Bool = false, open: Bool = true, project: String = "Atlas", provider: String = "codex"
    ) -> PanelItem {
        let route = PanelRoute(destinationId: UUID(), revision: 1, tabId: 1, windowId: 1)
        guard let key = try? ConversationKey(provider: provider, connectorId: Fixture.personal, providerConversationId: id) else {
            preconditionFailure("Invalid completion fixture identity")
        }
        return PanelItem(
            key: key, title: "Fix login", provider: provider, profileAlias: project, canonicalUrl: nil,
            pinned: false, hidden: hidden, availability: open ? .open([route]) : .unavailable(.sourceOffline),
            status: ItemStatus(display: display, freshness: freshness, ageSeconds: 0, turnEnd: end), sharesTitle: false
        )
    }
}
