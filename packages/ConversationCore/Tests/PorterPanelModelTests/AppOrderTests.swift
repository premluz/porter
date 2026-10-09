import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("Entries from a desktop app keep the app's own order when no time is known")
struct AppOrderTests {
    private func row(_ chat: String, title: String, rank: Int?, at seconds: TimeInterval? = nil) -> DestinationRow {
        DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: chat, provider: "claude-desktop",
            title: title, profileAlias: nil, connectorId: "desktopApp-1", reachability: .connected,
            tabId: nil, windowId: nil, url: nil, routeCount: 1,
            lastActiveAt: seconds.map { Fixture.now.addingTimeInterval($0) }, listRank: rank
        )
    }

    private func titles(_ rows: [DestinationRow]) -> [String] {
        Fixture.build(rows: rows, connectors: [Fixture.connector("desktopApp-1")]).open.map(\.title)
    }

    @Test("the app's list position wins over the alphabet")
    func positionBeatsAlphabet() {
        #expect(titles([row("a", title: "Zulu", rank: 0), row("b", title: "Alpha", rank: 1), row("c", title: "Mid", rank: 2)]) == ["Zulu", "Alpha", "Mid"])
    }

    @Test("a known time still beats a position, and entries with neither fall back to the alphabet")
    func timeFirstThenPosition() {
        let rows = [row("a", title: "Dated", rank: 5, at: -10), row("b", title: "First", rank: 0), row("c", title: "Second", rank: 1)]
        #expect(titles(rows) == ["Dated", "First", "Second"])
        #expect(titles([row("a", title: "Beta", rank: nil), row("b", title: "Alpha", rank: nil)]) == ["Alpha", "Beta"])
    }

    @Test("the most recent six are the app's first six, not the first six alphabetically")
    func recentSixFollowTheApp() {
        let rows = (0..<8).map { row("c\($0)", title: String(UnicodeScalar(UInt8(122 - $0))), rank: $0) }
        let split = Fixture.build(rows: rows, connectors: [Fixture.connector("desktopApp-1")]).recentSplit()
        #expect(split.recent.map(\.title) == ["z", "y", "x", "w", "v", "u"])
    }
}
