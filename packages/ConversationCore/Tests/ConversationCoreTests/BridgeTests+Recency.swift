import Foundation
import Testing
@testable import ConversationCore

@Suite("Recency of routes")
struct BridgeRecencyTests {
    private func browserTab(_ id: Int, chat: String, at stamp: String?) -> String {
        let recency = stamp.map { #","lastActiveAt":"\#($0)""# } ?? ""
        return #"{"tabId":\#(id),"windowId":1,"provider":"claude","providerConversationId":"\#(chat)","title":"T","canonicalUrl":"https://claude.ai/chat/\#(chat)"\#(recency)}"#
    }

    private func changes(_ harness: BridgeHarness) -> Int {
        harness.events.filter { if case .inventoryChanged = $0 { true } else { false } }.count
    }

    @Test("a browser route carries when it was last active, and a newer time reorders without touching the revision")
    func browserRecency() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[\#(browserTab(1, chat: "a", at: "2026-10-08T10:00:00Z"))]}"#)
        let first = try #require(harness.coordinator.rows().first)
        #expect(first.lastActiveAt == ISO8601DateFormatter().date(from: "2026-10-08T10:00:00Z"))
        let before = changes(harness)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[\#(browserTab(1, chat: "a", at: "2026-10-08T10:00:00Z"))]}"#)
        #expect(changes(harness) == before)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[\#(browserTab(1, chat: "a", at: "2026-10-08T10:05:00Z"))]}"#)
        let later = try #require(harness.coordinator.rows().first)
        #expect(later.revision == first.revision && later.destinationId == first.destinationId)
        #expect(later.lastActiveAt == ISO8601DateFormatter().date(from: "2026-10-08T10:05:00Z"))
        #expect(changes(harness) == before + 1)
    }

    @Test("a route without a reported time has none, and a gone route does not leave its time behind")
    func absenceAndPruning() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[\#(browserTab(1, chat: "a", at: nil))]}"#)
        #expect(harness.coordinator.rows().first?.lastActiveAt == nil)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[\#(browserTab(2, chat: "b", at: "2026-10-08T10:00:00Z"))]}"#)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[]}"#)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[\#(browserTab(2, chat: "b", at: nil))]}"#)
        #expect(harness.coordinator.rows().first?.lastActiveAt == nil)
    }

    @Test("an editor route carries its recency the same way")
    func editorRecency() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.editor(1)
        harness.helloEditor(client)
        func send(_ stamp: String) {
            harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"editorTabs":[{"provider":"claude-code","providerConversationId":"aaaa1111","title":"t","workspacePath":"/p","viewColumn":1,"index":0,"lastActiveAt":"\#(stamp)"}]}"#)
        }
        send("2026-10-08T10:00:00Z")
        let first = try #require(harness.coordinator.rows().first)
        let before = changes(harness)
        send("2026-10-08T10:00:00Z")
        #expect(changes(harness) == before)
        send("2026-10-08T11:00:00Z")
        let later = try #require(harness.coordinator.rows().first)
        #expect(later.revision == first.revision)
        #expect(later.lastActiveAt == ISO8601DateFormatter().date(from: "2026-10-08T11:00:00Z"))
    }

    @Test("a malformed recency value is refused whole, never read as a time")
    func badValue() {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[\#(browserTab(1, chat: "a", at: "yesterday"))]}"#)
        #expect(harness.wasClosed(client.connection))
        #expect(harness.coordinator.rows().isEmpty)
    }
}
