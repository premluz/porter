import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("Panel contents and states")
struct BuilderTests {
    @Test("no source connected, then connected but empty, are different empty states")
    func emptyStates() {
        #expect(Fixture.build(connectors: []).emptyState == .noSources)
        #expect(Fixture.build().emptyState == .noConversations)
        let withPlan = [Fixture.row("a", title: "Plan")]
        #expect(Fixture.build(rows: withPlan, query: "zzz").emptyState == .noMatches(query: "zzz"))
        #expect(Fixture.build(rows: withPlan).emptyState == nil)
    }

    @Test("identical titles in two profiles are separate items and both are flagged")
    func sharedTitles() {
        let snapshot = Fixture.build(
            rows: [
                Fixture.row("a", title: "Test", connector: Fixture.personal, alias: "Personal"),
                Fixture.row("b", title: "Test", connector: Fixture.work, alias: "Work"),
                Fixture.row("c", title: "Other"),
            ],
            connectors: [Fixture.connector(), Fixture.connector(Fixture.work, alias: "Work")]
        )
        #expect(snapshot.open.count == 3)
        #expect(snapshot.open.filter(\.sharesTitle).map(\.profileAlias) == ["Personal", "Work"])
        #expect(snapshot.open.first { $0.title == "Other" }?.sharesTitle == false)
    }

    @Test("the same chat reached from two profiles is not merged")
    func sameChatTwoProfiles() {
        let snapshot = Fixture.build(rows: [
            Fixture.row("same", connector: Fixture.personal, alias: "Personal"),
            Fixture.row("same", connector: Fixture.work, alias: "Work"),
        ])
        #expect(snapshot.open.count == 2)
    }

    @Test("two tabs of one chat become one ambiguous item with both routes")
    func ambiguousItem() {
        let snapshot = Fixture.build(rows: [Fixture.row("a", tab: 2), Fixture.row("a", tab: 1)])
        let item = snapshot.open[0]
        #expect(snapshot.open.count == 1)
        #expect(item.isAmbiguous)
        #expect(item.routes.map(\.tabId) == [1, 2])
    }

    @Test("a pin with its tab closed stays visible as closed, or as offline when its source is down")
    func closedPins() {
        let pin = Fixture.record("a")
        let closed = Fixture.build(records: [pin]).pinned[0]
        #expect(closed.availability == .unavailable(.closed))
        #expect(!closed.isOpenable)
        let offline = Fixture.build(connectors: [Fixture.connector(up: false)], records: [pin]).pinned[0]
        #expect(offline.availability == .unavailable(.sourceOffline))
        let unknownSource = Fixture.build(connectors: [], records: [pin]).pinned[0]
        #expect(unknownSource.availability == .unavailable(.sourceOffline))
    }

    @Test("a pin whose tab is open shows live routes and its pinned place, not a duplicate")
    func pinnedAndOpen() {
        let snapshot = Fixture.build(rows: [Fixture.row("a"), Fixture.row("b", title: "Other")], records: [Fixture.record("a")])
        #expect(snapshot.pinned.map(\.key.providerConversationId) == ["a"])
        #expect(snapshot.pinned[0].isOpenable)
        #expect(snapshot.open.map(\.key.providerConversationId) == ["b"])
    }

    @Test("pins follow the user's order")
    func pinOrder() {
        let snapshot = Fixture.build(records: [Fixture.record("a", order: 2), Fixture.record("b", order: 0), Fixture.record("c", order: 1)])
        #expect(snapshot.pinned.map(\.key.providerConversationId) == ["b", "c", "a"])
    }

    @Test("hidden items are left out unless asked for, and stay listed separately")
    func hiddenItems() {
        let rows = [Fixture.row("a"), Fixture.row("b", title: "Other")]
        let records = [Fixture.record("a", pinned: false, hidden: true)]
        let normal = Fixture.build(rows: rows, records: records)
        #expect(normal.open.map(\.key.providerConversationId) == ["b"])
        #expect(normal.hidden.map(\.key.providerConversationId) == ["a"])
        #expect(Fixture.build(rows: rows, records: records, showHidden: true).open.count == 2)
    }

    @Test("search matches title, provider and profile, all terms required")
    func search() {
        let rows = [Fixture.row("a", title: "Release plan", alias: "Work"), Fixture.row("b", title: "Release notes", alias: "Personal")]
        #expect(Fixture.build(rows: rows, query: "release work").open.map(\.title) == ["Release plan"])
        #expect(Fixture.build(rows: rows, query: "RELEASE").open.count == 2)
        #expect(Fixture.build(rows: rows, query: "claude personal").open.map(\.title) == ["Release notes"])
    }

    @Test("rows with an unreadable key are reported, not silently dropped")
    func unreadableRows() {
        let bad = Fixture.row("has space")
        let snapshot = Fixture.build(rows: [bad, Fixture.row("a")])
        #expect(snapshot.open.count == 1)
        #expect(snapshot.unreadable.count == 1)
    }

    @Test("frozen order keeps what is on screen in place and puts new items last")
    func frozenOrder() {
        let rows = [Fixture.row("a", title: "Alpha"), Fixture.row("b", title: "Beta")]
        let natural = Fixture.build(rows: rows).open.map(\.id)
        let frozen = Array(natural.reversed())
        let later = Fixture.build(rows: rows + [Fixture.row("c", title: "Aardvark")], frozen: frozen).open.map(\.key.providerConversationId)
        #expect(later == ["b", "a", "c"])
    }

    @Test("status: unknown by default, fresh shows, stale never reads as live")
    func statuses() {
        let row = Fixture.row("a")
        let observation = Sample.observation(destinationId: row.destinationId, activity: .working, receivedAt: Fixture.now.addingTimeInterval(-30))
        let fresh = DestinationStatus(display: .working, freshness: .fresh, reachability: .connected, lastKnown: observation)
        let stale = DestinationStatus(display: .unknown, freshness: .stale, reachability: .connected, lastKnown: observation)
        let none = Fixture.build(rows: [row]).open[0].status
        let live = Fixture.build(rows: [row], statuses: [row.destinationId: fresh]).open[0].status
        let old = Fixture.build(rows: [row], statuses: [row.destinationId: stale]).open[0].status
        #expect(StatusPresentation.label(for: none) == "Unknown")
        #expect(StatusPresentation.label(for: live) == "Working")
        #expect(live.ageSeconds == 30)
        #expect(StatusPresentation.label(for: old) == "Last seen working just now")
        #expect(old.freshness == .stale && old.display == .unknown)
    }
}
