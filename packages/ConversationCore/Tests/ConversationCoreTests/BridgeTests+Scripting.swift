import Foundation
import Testing
@testable import ConversationCore

@Suite("A connector that reads Chrome by scripting, with no extension")
struct BridgeScriptingTests {
    private func connected() -> (BridgeHarness, BridgeHarness.Client) {
        var harness = BridgeHarness()
        let client = BridgeHarness.Client(connection: ConnectionID(1), installationId: UUID(), epoch: "epoch-1", kind: .chromeScripting)
        harness.send(client, type: "hello", payload: #"{"installationId":"\#(client.installationId.uuidString)","connectorKind":"chromeScripting","adapterVersions":{"claude":"0.1.0"}}"#)
        harness.snapshot(client, tabs: [(tab: 101, window: 7, chat: "a", title: "Alpha")])
        return (harness, client)
    }

    @Test("it gets its own kind-prefixed ID and its routes carry no profile")
    func identityAndRows() throws {
        let (harness, client) = connected()
        #expect(client.connectorId.hasPrefix("chromeScripting-"))
        let row = try #require(harness.coordinator.rows().first)
        #expect(row.profileAlias == nil && row.tabId == 101 && row.windowId == 7 && row.title == "Alpha")
        let summary = try #require(harness.coordinator.connectorSummaries().first)
        #expect(summary.providerType == .chromeScripting && summary.routeCount == 1)
    }

    @Test("like a browser connector it may send incremental updates, and may not report editor tabs")
    func browserRules() throws {
        var (harness, client) = connected()
        let tab = #"{"tabId":102,"windowId":7,"provider":"claude","providerConversationId":"b","title":"Beta","canonicalUrl":"https://claude.ai/chat/b"}"#
        harness.send(client, type: "destination.upsert", payload: #"{"tab":\#(tab)}"#)
        #expect(harness.coordinator.rows().count == 2)
        harness.editorSnapshot(client, tabs: [("c1", "Nope", "/x", 1, 0)])
        #expect(try harness.errorCodes(to: client.connection) == [.unauthorized])
        #expect(harness.wasClosed(client.connection))
    }

    @Test("a hello claiming this kind with another kind's ID is refused")
    func kindMustMatchId() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.Client(connection: ConnectionID(1), installationId: UUID(), epoch: "e", kind: .chromeScripting)
        let extensionId = BridgeCoordinator.connectorId(for: client.installationId, kind: .chrome)
        harness.send(client, type: "hello", payload: #"{"installationId":"\#(client.installationId.uuidString)","connectorKind":"chromeScripting","adapterVersions":{"claude":"0.1.0"}}"#, connectorId: extensionId)
        #expect(try harness.errorCodes(to: client.connection) == [.unauthorized])
    }
}
