import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("The pane lists the six most recent open conversations and folds the rest")
struct RecentSplitTests {
    private func rows(_ count: Int) -> [DestinationRow] {
        (0..<count).map { index in
            DestinationRow(
                destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: "c\(index)", provider: "claude",
                title: "Chat \(index)", profileAlias: "Personal", connectorId: Fixture.personal, reachability: .connected,
                tabId: index + 1, windowId: 1, url: "https://claude.ai/chat/c\(index)", routeCount: 1,
                lastActiveAt: Fixture.now.addingTimeInterval(-TimeInterval(index) * 60)
            )
        }
    }

    @Test("the six newest are recent, the rest are older, and order is kept")
    func splitsAtSix() {
        let split = Fixture.build(rows: rows(9)).recentSplit()
        #expect(split.recent.map(\.title) == (0..<6).map { "Chat \($0)" })
        #expect(split.older.map(\.title) == ["Chat 6", "Chat 7", "Chat 8"])
    }

    @Test("six or fewer leaves nothing folded")
    func nothingToFold() {
        #expect(Fixture.build(rows: rows(6)).recentSplit().older.isEmpty)
        #expect(Fixture.build(rows: rows(2)).recentSplit().recent.count == 2)
    }

    @Test("the folded group is reachable by navigation only while it is shown")
    func navigationFollowsFold() {
        let snapshot = Fixture.build(rows: rows(8))
        #expect(snapshot.navigable(showingOlder: false).count == 6)
        #expect(snapshot.navigable(showingOlder: true).map(\.title) == snapshot.open.map(\.title))
    }

    @Test("pinned conversations do not count toward the six")
    func pinsAreSeparate() {
        let snapshot = Fixture.build(rows: rows(8), records: [Fixture.record("c0", order: 0)])
        #expect(snapshot.pinned.count == 1)
        #expect(snapshot.recentSplit().recent.count == 6 && snapshot.recentSplit().older.count == 1)
        #expect(snapshot.navigable(showingOlder: false).count == 7)
    }
}
