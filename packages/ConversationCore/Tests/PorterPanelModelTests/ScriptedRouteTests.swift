import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("Extension routes win over scripted ones for the same conversation")
struct ScriptedRouteTests {
    private let scriptedId = "chromeScripting-1"

    private func scripted() -> ConnectorSummary {
        ConnectorSummary(connectorId: scriptedId, profileAlias: nil, reachability: .connected, routeCount: 0, providerType: .chromeScripting)
    }

    private func scriptedRow(_ chat: String, title: String = "Plan") -> DestinationRow {
        Fixture.row(chat, title: title, connector: scriptedId, alias: "")
    }

    @Test("a chat seen by both appears once, through the extension")
    func duplicateCollapses() {
        let snapshot = Fixture.build(
            rows: [Fixture.row("a"), scriptedRow("a")], connectors: [Fixture.connector(), scripted()]
        )
        #expect(snapshot.open.count == 1)
        #expect(snapshot.open.first?.key.connectorId == Fixture.personal)
    }

    @Test("a chat only scripting sees stays, and a chat only the extension sees stays")
    func uniqueRoutesStay() {
        let snapshot = Fixture.build(
            rows: [Fixture.row("a"), scriptedRow("b", title: "Scripted only")], connectors: [Fixture.connector(), scripted()]
        )
        #expect(Set(snapshot.open.map(\.title)) == ["Plan", "Scripted only"])
    }

    @Test("with no scripted connector nothing is filtered")
    func noScriptedConnector() {
        let rows = [Fixture.row("a"), Fixture.row("a", connector: Fixture.work, alias: "Work")]
        #expect(PanelBuilder.preferringEnhancedRoutes(rows, connectors: [Fixture.connector()]).count == 2)
    }

    @Test("a different provider with the same chat id is not mistaken for a duplicate")
    func providerMatters() {
        let other = DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: "a", provider: "chatgpt",
            title: "Other", profileAlias: nil, connectorId: scriptedId, reachability: .connected,
            tabId: 5, windowId: 1, url: "https://chatgpt.com/c/a", routeCount: 1
        )
        let rows = [Fixture.row("a"), other]
        #expect(PanelBuilder.preferringEnhancedRoutes(rows, connectors: [Fixture.connector(), scripted()]).count == 2)
    }
}

@Suite("Codex's thread list stands in for its editor tabs")
struct CodexTabSupersessionTests {
    private func row(_ chat: String, connector: String, provider: String = "codex") -> DestinationRow {
        DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: chat, provider: provider,
            title: chat, profileAlias: "Atlas", connectorId: connector, reachability: .connected, tabId: nil,
            windowId: nil, url: nil, routeCount: 1
        )
    }

    private let connectors = [
        ConnectorSummary(connectorId: "desktopApp-1", profileAlias: nil, reachability: .connected, routeCount: 1, providerType: .desktopApp),
        ConnectorSummary(connectorId: "vscode-1", profileAlias: "Atlas", reachability: .connected, routeCount: 2, providerType: .vscodeExtension),
    ]

    @Test("with the thread list present, a window's Codex tabs are dropped and its other routes stay")
    func dropsTabs() {
        let rows = [
            row("thread-a", connector: "desktopApp-1"), row("tab-a", connector: "vscode-1"),
            row("claude-tab", connector: "vscode-1", provider: "claude-code"),
        ]
        let kept = PanelBuilder.preferringEnhancedRoutes(rows, connectors: connectors).map(\.providerConversationId)
        #expect(kept == ["thread-a", "claude-tab"])
    }

    @Test("with no Codex thread routes, the editor tabs are kept")
    func keepsTabsWithoutList() {
        let rows = [row("tab-a", connector: "vscode-1"), row("claude-app", connector: "desktopApp-1", provider: "claude-desktop")]
        #expect(PanelBuilder.preferringEnhancedRoutes(rows, connectors: connectors).count == 2)
    }
}
