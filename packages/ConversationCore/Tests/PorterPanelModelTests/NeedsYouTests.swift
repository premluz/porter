import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("What is waiting on the person comes first")
struct NeedsYouTests {
    private func status(_ display: DisplayStatus, for row: DestinationRow, fresh: Bool = true, secondsAgo: TimeInterval = 5) -> DestinationStatus {
        let observation = Sample.observation(
            destinationId: row.destinationId, activity: .idle, attention: .needsUser, receivedAt: Fixture.now.addingTimeInterval(-secondsAgo)
        )
        return DestinationStatus(display: display, freshness: fresh ? .fresh : .stale, reachability: .connected, lastKnown: observation)
    }

    @Test("a fresh needs-you chat is listed first and not again among the open ones")
    func listedOnce() {
        let waiting = Fixture.row("a", title: "Needs an answer", tab: 1)
        let other = Fixture.row("b", title: "Aardvark", tab: 2)
        let snapshot = Fixture.build(rows: [other, waiting], statuses: [waiting.destinationId: status(.needsUser, for: waiting)])
        #expect(snapshot.needsYou.map(\.title) == ["Needs an answer"])
        #expect(snapshot.open.map(\.title) == ["Aardvark"])
        #expect(snapshot.navigable.map(\.title) == ["Needs an answer", "Aardvark"])
    }

    @Test("a stale signal, or any other state, is not promoted")
    func onlyFreshNeeds() {
        let stale = Fixture.row("a", title: "Old question", tab: 1)
        let working = Fixture.row("b", title: "Busy", tab: 2)
        let snapshot = Fixture.build(
            rows: [stale, working],
            statuses: [stale.destinationId: status(.needsUser, for: stale, fresh: false), working.destinationId: status(.working, for: working)]
        )
        #expect(snapshot.needsYou.isEmpty && snapshot.open.count == 2)
    }

    @Test("a pinned chat that needs you moves up out of the pinned list; the newest question leads")
    func pinnedAndOrder() {
        let older = Fixture.row("a", title: "Older question", tab: 1)
        let newer = Fixture.row("b", title: "Newer question", tab: 2)
        let snapshot = Fixture.build(
            rows: [older, newer], records: [Fixture.record("a", order: 0)],
            statuses: [older.destinationId: status(.needsUser, for: older, secondsAgo: 600), newer.destinationId: status(.needsUser, for: newer, secondsAgo: 5)]
        )
        #expect(snapshot.needsYou.map(\.title) == ["Newer question", "Older question"])
        #expect(snapshot.pinned.isEmpty && snapshot.open.isEmpty)
    }
}
