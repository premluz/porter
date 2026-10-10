import Foundation
import Testing
@testable import ConversationCore

@Suite("Opening a chat from Porter does not make it the most recently used")
struct OwnActivationRecencyTests {
    private func iso(_ date: Date) -> String { date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)) }

    private func report(_ harness: inout BridgeHarness, _ client: BridgeHarness.Client, tab: Int, chat: String, seen: Date?) {
        let time = seen.map { #","lastActiveAt":"\#(iso($0))""# } ?? ""
        let entry = #"{"tabId":\#(tab),"windowId":1,"provider":"claude","providerConversationId":"\#(chat)","title":"\#(chat)","canonicalUrl":"https://claude.ai/chat/\#(chat)"\#(time)}"#
        harness.send(client, type: "destination.upsert", payload: #"{"tab":\#(entry)}"#)
    }

    @Test("a time reported just after the click is ignored, even when it is repeated later, and a later real use counts")
    func clickIsNotUse() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client)
        let earlier = harness.now.addingTimeInterval(-3_600)
        report(&harness, client, tab: 1, chat: "a", seen: earlier)
        let row = try #require(harness.coordinator.rows().first)
        #expect(row.lastActiveAt == earlier)

        _ = harness.coordinator.requestActivation(destinationId: row.destinationId, expectedRevision: row.revision, now: harness.now)
        let clickEcho = harness.now.addingTimeInterval(2)
        report(&harness, client, tab: 1, chat: "a", seen: clickEcho)
        #expect(harness.coordinator.rows().first?.lastActiveAt == earlier)
        // The connector keeps reporting the same stamp; it must stay ignored once the window has passed.
        harness.now = harness.now.addingTimeInterval(600)
        report(&harness, client, tab: 1, chat: "a", seen: clickEcho)
        #expect(harness.coordinator.rows().first?.lastActiveAt == earlier)
        let realUse = harness.now.addingTimeInterval(1)
        report(&harness, client, tab: 1, chat: "a", seen: realUse)
        #expect(harness.coordinator.rows().first?.lastActiveAt == realUse)
    }

    @Test("the other chats are unaffected, so using one elsewhere still moves it")
    func otherRoutesCount() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client)
        report(&harness, client, tab: 1, chat: "a", seen: nil)
        report(&harness, client, tab: 2, chat: "b", seen: nil)
        let rows = harness.coordinator.rows()
        let first = try #require(rows.first { $0.providerConversationId == "a" })
        _ = harness.coordinator.requestActivation(destinationId: first.destinationId, expectedRevision: first.revision, now: harness.now)
        let used = harness.now.addingTimeInterval(1)
        report(&harness, client, tab: 2, chat: "b", seen: used)
        #expect(harness.coordinator.rows().first { $0.providerConversationId == "b" }?.lastActiveAt == used)
    }

    @Test("rows say whether a chat lives in a browser, VS Code or an app")
    func sources() {
        var harness = BridgeHarness()
        let browser = BridgeHarness.client(1)
        harness.hello(browser)
        report(&harness, browser, tab: 1, chat: "a", seen: nil)
        let editor = BridgeHarness.editor(2)
        harness.helloEditor(editor)
        harness.editorSnapshot(editor, tabs: [("aaaa1111", "Plan", "/Users/example/Porter", 1, 0)])
        let app = BridgeHarness.Client(connection: ConnectionID(3), installationId: UUID(), epoch: "e", kind: .desktopApp)
        harness.send(app, type: "hello", payload: #"{"installationId":"\#(app.installationId.uuidString)","connectorKind":"desktopApp","adapterVersions":{"claude-desktop":"0.1.0"}}"#)
        harness.send(app, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[{"provider":"claude-desktop","providerConversationId":"x-0","title":"In app","bundleId":"com.anthropic.claudefordesktop","ordinal":0}]}"#)
        let found = Dictionary(uniqueKeysWithValues: harness.coordinator.rows().map { ($0.title, $0.source?.label) })
        #expect(found == ["a": "Browser", "Plan": "VS Code", "In app": "App"])
    }

    @Test("an agent in a terminal says Terminal, and one hosted in VS Code's terminal says VS Code")
    func terminalSource() {
        var harness = BridgeHarness()
        let app = BridgeHarness.Client(connection: ConnectionID(1), installationId: UUID(), epoch: "e", kind: .desktopApp)
        harness.send(app, type: "hello", payload: #"{"installationId":"\#(app.installationId.uuidString)","connectorKind":"desktopApp","adapterVersions":{"claude-code":"0.1.0"}}"#)
        func entry(_ id: String, _ bundle: String) -> String {
            #"{"provider":"claude-code","providerConversationId":"\#(id)","title":"\#(id)","bundleId":"\#(bundle)","ordinal":0,"workspacePath":"/Users/example/Atlas"}"#
        }
        harness.send(app, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entry("in-terminal", "com.apple.Terminal")),\#(entry("in-code", "com.microsoft.VSCode"))]}"#)
        let found = Dictionary(uniqueKeysWithValues: harness.coordinator.rows().map { ($0.title, $0.source?.label) })
        #expect(found == ["in-terminal": "Terminal", "in-code": "VS Code"])
    }
}
