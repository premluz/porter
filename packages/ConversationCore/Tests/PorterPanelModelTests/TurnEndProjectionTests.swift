import ConversationCore
import Testing
@testable import PorterPanelModel

@Suite("Turn-end evidence across several routes")
struct TurnEndProjectionTests {
    @Test(arguments: [Freshness.stale, .unknown])
    func freshWorkDoesNotMakeAnotherRoutesEndFresh(_ freshness: Freshness) throws {
        let live = Fixture.row("same-chat", tab: 1)
        let lost = Fixture.row("same-chat", tab: 2, reachability: .disconnected)
        let working = DestinationStatus(display: .working, freshness: .fresh, reachability: .connected, lastKnown: nil)
        let end = TurnEnd(at: Fixture.now, kind: .completed)
        let stale = DestinationStatus(display: .unknown, freshness: freshness, reachability: .disconnected, lastKnown: nil, turnEnd: end)
        let snapshot = Fixture.build(rows: [live, lost], statuses: [live.destinationId: working, lost.destinationId: stale])
        let item = try #require(snapshot.open.first)
        #expect(item.status.display == .working)
        #expect(item.status.turnEnd == nil)
    }

    @Test func freshConnectedEndIsPreserved() throws {
        let row = Fixture.row("completed-chat")
        let end = TurnEnd(at: Fixture.now, kind: .completed)
        let status = DestinationStatus(display: .idle, freshness: .fresh, reachability: .connected, lastKnown: nil, turnEnd: end)
        let snapshot = Fixture.build(rows: [row], statuses: [row.destinationId: status])
        #expect(try #require(snapshot.open.first).status.turnEnd == end)
    }
}
