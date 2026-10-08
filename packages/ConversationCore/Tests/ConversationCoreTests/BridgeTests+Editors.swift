import Foundation
import Testing
@testable import ConversationCore

@Suite("Editor connectors (VS Code)")
struct BridgeEditorTests {
    private let folder = "/Users/example/Porter"

    private func connected(
        folder name: String = "Porter", path: String = "/Users/example/Porter",
        tabs: [(id: String, title: String, path: String, column: Int, index: Int)]? = nil
    ) -> (BridgeHarness, BridgeHarness.Client) {
        var harness = BridgeHarness()
        let client = BridgeHarness.editor(1)
        harness.helloEditor(client, folder: name)
        harness.editorSnapshot(client, tabs: tabs ?? [("aaaa1111", "Release plan", path, 1, 0)])
        return (harness, client)
    }

    @Test("an editor connector is acknowledged with its own kind-prefixed ID")
    func helloAccepted() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.editor(1)
        harness.helloEditor(client)
        #expect(client.connectorId.hasPrefix("vscode-"))
        #expect(try harness.messages(to: client.connection).first?.body == .helloAck(HelloAckPayload(accepted: true, connectorId: client.connectorId)))
    }

    @Test("an editor hello that claims a browser connector ID is refused")
    func kindMustMatchId() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.editor(1)
        let browserId = BridgeCoordinator.connectorId(for: client.installationId, kind: .chrome)
        harness.send(client, type: "hello", payload: #"{"installationId":"\#(client.installationId)","connectorKind":"vscode","adapterVersions":{"claude-code":"0.1.0"}}"#, connectorId: browserId)
        #expect(try harness.errorCodes(to: client.connection) == [.unauthorized])
        #expect(harness.wasClosed(client.connection))
    }

    @Test("editor tabs become routes labelled with the folder, with no browser fields")
    func rows() throws {
        let (harness, _) = connected()
        let row = try #require(harness.coordinator.rows().first)
        #expect(row.provider == "claude-code" && row.profileAlias == "Porter" && row.title == "Release plan")
        #expect(row.tabId == nil && row.windowId == nil && row.url == nil)
        #expect(row.reachability == .connected)
        #expect(harness.coordinator.connectorSummaries().first?.routeCount == 1)
    }

    @Test("the same title in two windows, or twice in one window, stays separate")
    func identicalTitles() {
        var harness = BridgeHarness()
        let one = BridgeHarness.editor(1)
        let two = BridgeHarness.editor(2)
        harness.helloEditor(one, folder: "Porter")
        harness.helloEditor(two, folder: "Merlin")
        harness.editorSnapshot(one, tabs: [("aaaa0001", "Notes", "/p/Porter", 1, 0), ("aaaa0002", "Notes", "/p/Porter", 1, 1)])
        harness.editorSnapshot(two, tabs: [("bbbb0001", "Notes", "/p/Merlin", 1, 0)])
        let rows = harness.coordinator.rows()
        #expect(rows.count == 3)
        #expect(Set(rows.map(\.conversationId)).count == 3)
        #expect(rows.filter { $0.profileAlias == "Porter" }.count == 2)
    }

    @Test("moving a tab keeps its route and raises the revision; closing it removes the route")
    func moveAndClose() throws {
        var (harness, client) = connected()
        let before = try #require(harness.coordinator.rows().first)
        harness.editorSnapshot(client, tabs: [("aaaa1111", "Release plan", folder, 2, 3)])
        let moved = try #require(harness.coordinator.rows().first)
        #expect(moved.destinationId == before.destinationId && moved.revision > before.revision)
        harness.editorSnapshot(client, tabs: [])
        #expect(harness.coordinator.rows().isEmpty)
    }

    @Test("an identical snapshot changes nothing and reports no change")
    func stableSnapshot() {
        var (harness, client) = connected()
        let before = harness.coordinator.rows()
        let events = harness.events.count
        harness.editorSnapshot(client, tabs: [("aaaa1111", "Release plan", folder, 1, 0)])
        #expect(harness.coordinator.rows() == before)
        #expect(harness.events.count == events)
    }

    @Test("kinds cannot be mixed: browser tabs from an editor, editor tabs from a browser, incremental messages from an editor")
    func crossKindForgery() throws {
        var editor = BridgeHarness()
        let client = BridgeHarness.editor(1)
        editor.helloEditor(client)
        editor.snapshot(client, tabs: [(1, 1, "chat-a", "A")])
        #expect(editor.wasClosed(client.connection))

        var incremental = BridgeHarness()
        let second = BridgeHarness.editor(1)
        incremental.helloEditor(second)
        incremental.send(second, type: "destination.remove", payload: #"{"tabId":1}"#)
        #expect(incremental.wasClosed(second.connection))

        var browser = BridgeHarness()
        let chrome = BridgeHarness.client(1)
        browser.hello(chrome)
        browser.send(chrome, type: "inventory.snapshot", payload: #"{"tabs":[],"editorTabs":[{"provider":"claude","providerConversationId":"x","title":"t","workspacePath":"/p","viewColumn":1,"index":0}]}"#)
        #expect(browser.wasClosed(chrome.connection))
        #expect(browser.coordinator.rows().isEmpty)
    }

    @Test("an editor connector cannot report a provider it did not declare")
    func undeclaredProvider() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.editor(1)
        harness.helloEditor(client, providers: ["claude-code"])
        harness.editorSnapshot(client, tabs: [("aaaa1111", "t", folder, 1, 0)], provider: "chatgpt")
        #expect(try harness.errorCodes(to: client.connection) == [.unauthorized])
        #expect(harness.coordinator.rows().isEmpty)
    }

    @Test("hostile editor tabs are refused whole: relative path, traversal, bad position, duplicates")
    func hostileTabs() {
        let bad: [(id: String, title: String, path: String, column: Int, index: Int)] = [
            ("aaaa1111", "t", "relative/path", 1, 0), ("aaaa1111", "t", "/Users/x/../etc", 1, 0),
            ("aaaa1111", "t", "/p", 9, 0), ("aaaa1111", "t", "/p", 1, 9), ("has space", "t", "/p", 1, 0),
        ]
        for tab in bad {
            var harness = BridgeHarness()
            let client = BridgeHarness.editor(1)
            harness.helloEditor(client)
            harness.editorSnapshot(client, tabs: [tab])
            #expect(harness.wasClosed(client.connection), "\(tab)")
            #expect(harness.coordinator.rows().isEmpty, "\(tab)")
        }
        var harness = BridgeHarness()
        let client = BridgeHarness.editor(1)
        harness.helloEditor(client)
        harness.editorSnapshot(client, tabs: [("same0001", "a", "/p", 1, 0), ("same0001", "b", "/p", 1, 1)])
        #expect(harness.wasClosed(client.connection))
    }

    @Test("activation first asks the host to bring the window forward, then carries the title to verify")
    func activationPreparation() throws {
        var (harness, client) = connected()
        let row = try #require(harness.coordinator.rows().first)
        let start = harness.coordinator.requestActivation(destinationId: row.destinationId, expectedRevision: row.revision, now: harness.now)
        guard case .dispatchedAfterPreparation(_, let outbound, let preparation) = start else { Issue.record("got \(start)"); return }
        #expect(preparation == ActivationPreparation(bundleId: "com.microsoft.VSCode", workspacePath: folder))
        harness.record(BridgeResult(outbound: outbound))
        let request = try #require(try harness.messages(to: client.connection).last)
        guard case .activateRequest(let payload) = request.body else { Issue.record("no request"); return }
        #expect(payload.tabId == nil && payload.windowId == nil)
        #expect(payload.editor == EditorTarget(workspacePath: folder, viewColumn: 1, index: 0, expectedTitle: "Release plan"))
        #expect(payload.expectedProvider == "claude-code" && payload.expectedConversationId == "aaaa1111")
    }

    @Test("a stale revision or a closed tab is refused before anything is prepared")
    func staleRefused() throws {
        var (harness, client) = connected()
        let row = try #require(harness.coordinator.rows().first)
        harness.editorSnapshot(client, tabs: [("aaaa1111", "Release plan", folder, 1, 4)])
        guard case .refused(let changed) = harness.coordinator.requestActivation(destinationId: row.destinationId, expectedRevision: row.revision, now: harness.now) else { Issue.record("expected refusal"); return }
        #expect(changed.outcome == .targetChanged)
        harness.editorSnapshot(client, tabs: [])
        guard case .refused(let gone) = harness.coordinator.requestActivation(destinationId: row.destinationId, expectedRevision: row.revision, now: harness.now) else { Issue.record("expected refusal"); return }
        #expect(gone.outcome == .targetGone)
    }

    @Test("a disconnected window reports offline and a reconnect starts with no old routes")
    func disconnectAndReconnect() throws {
        var (harness, client) = connected()
        let row = try #require(harness.coordinator.rows().first)
        harness.record(harness.coordinator.disconnect(client.connection, now: harness.now))
        guard case .refused(let offline) = harness.coordinator.requestActivation(destinationId: row.destinationId, expectedRevision: row.revision, now: harness.now) else { Issue.record("expected refusal"); return }
        #expect(offline.outcome == .connectorOffline)
        let restarted = BridgeHarness.Client(connection: ConnectionID(2), installationId: client.installationId, epoch: "epoch-2", kind: .vscode)
        harness.helloEditor(restarted)
        #expect(harness.coordinator.rows().isEmpty)
    }

    @Test("the registry accepts only VS Code editor locators with plain absolute paths")
    func locatorPolicy() {
        let policy = LocatorPolicy()
        func locator(_ bundle: String, _ path: String, _ column: Int = 1, _ index: Int = 0) -> Locator {
            .editorTab(EditorTabLocator(bundleId: bundle, workspacePath: path, viewColumn: column, index: index))
        }
        #expect(throws: Never.self) { try policy.validate(locator("com.microsoft.VSCode", "/Users/a/b")) }
        #expect(throws: LocatorRejection.unsupportedEditor("com.example.Editor")) { try policy.validate(locator("com.example.Editor", "/a")) }
        #expect(throws: LocatorRejection.invalidWorkspacePath) { try policy.validate(locator("com.microsoft.VSCode", "relative")) }
        #expect(throws: LocatorRejection.invalidWorkspacePath) { try policy.validate(locator("com.microsoft.VSCode", "/a/../b")) }
        #expect(throws: LocatorRejection.invalidEditorPosition) { try policy.validate(locator("com.microsoft.VSCode", "/a", 0, 0)) }
    }
}
