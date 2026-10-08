import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("The Open list shows the most recently used first")
struct RecencyOrderTests {
    private func row(_ chat: String, title: String, at seconds: TimeInterval?, tab: Int = 1) -> DestinationRow {
        DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: chat, provider: "claude",
            title: title, profileAlias: "Personal", connectorId: Fixture.personal, reachability: .connected, tabId: tab,
            windowId: 1, url: "https://claude.ai/chat/\(chat)", routeCount: 1,
            lastActiveAt: seconds.map { Fixture.now.addingTimeInterval($0) }
        )
    }

    private func titles(_ rows: [DestinationRow], pins: [String] = [], frozen: [String]? = nil) -> [String] {
        let records = pins.enumerated().map { Fixture.record($1, order: $0) }
        return Fixture.build(rows: rows, records: records, frozen: frozen).open.map(\.title)
    }

    @Test("newest first, regardless of title")
    func newestFirst() {
        let rows = [row("a", title: "Alpha", at: -300), row("b", title: "Beta", at: -10), row("c", title: "Gamma", at: -100)]
        #expect(titles(rows) == ["Beta", "Gamma", "Alpha"])
    }

    @Test("items with no reported time come after every dated one, in a stable order")
    func unknownLast() {
        let rows = [row("a", title: "Zulu", at: nil, tab: 1), row("b", title: "Alpha", at: nil, tab: 2), row("c", title: "Mid", at: -500)]
        #expect(titles(rows) == ["Mid", "Alpha", "Zulu"])
    }

    @Test("equal times fall back to the stable order, so the list never shuffles by chance")
    func ties() {
        let rows = [row("a", title: "Beta", at: -50), row("b", title: "Alpha", at: -50)]
        #expect(titles(rows) == ["Alpha", "Beta"])
        #expect(titles(rows.reversed()) == ["Alpha", "Beta"])
    }

    @Test("an item open in two tabs takes the later of the two times")
    func routesUseLatest() {
        let rows = [
            row("a", title: "Twin", at: -500, tab: 1), row("a", title: "Twin", at: -5, tab: 2),
            row("b", title: "Single", at: -100),
        ]
        #expect(titles(rows) == ["Twin", "Single"])
    }

    @Test("pinned items keep the user's order and are not reordered by recency")
    func pinsIgnoreRecency() {
        let rows = [row("a", title: "Old pin", at: -900), row("b", title: "New pin", at: -1)]
        let snapshot = Fixture.build(rows: rows, records: [Fixture.record("a", order: 0), Fixture.record("b", order: 1)])
        #expect(snapshot.pinned.map(\.title) == ["Old pin", "New pin"])
        #expect(snapshot.open.isEmpty)
    }

    @Test("while the pane is open the order on screen is kept, and a newly used chat joins at the end")
    func frozenWhileOpen() {
        let rows = [row("a", title: "Alpha", at: -300), row("b", title: "Beta", at: -100)]
        let onScreen = Fixture.build(rows: rows).open.map(\.id)
        let later = rows + [row("c", title: "Gamma", at: -1)]
        #expect(titles(later, frozen: onScreen) == ["Beta", "Alpha", "Gamma"])
        #expect(titles(later) == ["Gamma", "Beta", "Alpha"])
    }
}
