import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("Completions group in a stable bounded window")
struct CompletionCoalescerTests {
    @Test("arrivals share the first deadline and deadline boundary starts a new batch")
    func fixedWindow() {
        var coalescer = CompletionCoalescer(window: 1)
        #expect(coalescer.append([event("a")], now: Fixture.now).isEmpty)
        #expect(coalescer.nextFlushAt == Fixture.now.addingTimeInterval(1))
        #expect(coalescer.append([event("b")], now: Fixture.now.addingTimeInterval(0.9)).isEmpty)
        #expect(coalescer.nextFlushAt == Fixture.now.addingTimeInterval(1))
        let ready = coalescer.append([event("c")], now: Fixture.now.addingTimeInterval(1))
        #expect(ready.count == 1 && ready.first?.completions.map(\.id) == ["a", "b"])
        #expect(coalescer.nextFlushAt == Fixture.now.addingTimeInterval(2))
        #expect(coalescer.flush(now: Fixture.now.addingTimeInterval(2)).first?.completions.map(\.id) == ["c"])
        #expect(coalescer.nextFlushAt == nil)
        #expect(coalescer.flush(now: Fixture.now.addingTimeInterval(3)).isEmpty)
    }

    @Test("interrupted tasks cannot inflate the completed task count")
    func mixedKinds() {
        var coalescer = CompletionCoalescer(window: 1)
        _ = coalescer.append([event("a"), event("b", kind: .interrupted), event("c")], now: Fixture.now)
        let batches = coalescer.flush(now: Fixture.now.addingTimeInterval(1))
        #expect(batches.map(\.kind) == [.completed, .interrupted])
        #expect(batches.map { $0.completions.map(\.id) } == [["a", "c"], ["b"]])
    }

    @Test("newest event for an identity wins, while same titles across identities remain separate")
    func stableIdentities() {
        var coalescer = CompletionCoalescer(window: 1)
        _ = coalescer.append([event("a"), event("b")], now: Fixture.now)
        _ = coalescer.append([event("a", kind: .interrupted, offset: 1)], now: Fixture.now.addingTimeInterval(0.5))
        _ = coalescer.append([event("a", offset: -1)], now: Fixture.now.addingTimeInterval(0.75))
        let batches = coalescer.flush(now: Fixture.now.addingTimeInterval(1))
        #expect(batches.map { $0.completions.map(\.id) } == [["b"], ["a"]])
        #expect(batches.allSatisfy { $0.completions.allSatisfy { $0.title == "Fix login" } })
    }

    @Test("empty updates never create a timer and an empty append can flush pending work")
    func empty() {
        var coalescer = CompletionCoalescer(window: 1)
        #expect(coalescer.append([], now: Fixture.now).isEmpty && coalescer.nextFlushAt == nil)
        _ = coalescer.append([event("a")], now: Fixture.now)
        #expect(coalescer.append([], now: Fixture.now.addingTimeInterval(1)).count == 1)
        #expect(coalescer.nextFlushAt == nil)
    }

    private func event(_ id: String, kind: TurnEndKind = .completed, offset: TimeInterval = 0) -> Completion {
        Completion(id: id, title: "Fix login", projectName: "Atlas", end: TurnEnd(at: Fixture.now.addingTimeInterval(offset), kind: kind))
    }
}
