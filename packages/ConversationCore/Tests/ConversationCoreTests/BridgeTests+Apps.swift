import Foundation
import Testing
@testable import ConversationCore

@Suite("Desktop-app connectors (Claude and ChatGPT apps)")
struct BridgeAppTests {
    private let claude = "com.anthropic.claudefordesktop"

    private func entry(_ id: String, _ title: String, ordinal: Int = 0, provider: String = "claude-desktop", unread: Bool? = nil) -> String {
        let unreadJSON = unread.map { #","unread":\#($0)"# } ?? ""
        return #"{"provider":"\#(provider)","providerConversationId":"\#(id)","title":"\#(title)","bundleId":"\#(claude)","ordinal":\#(ordinal)\#(unreadJSON)}"#
    }

    private func connected(_ entries: [String]? = nil) -> (BridgeHarness, BridgeHarness.Client) {
        var harness = BridgeHarness()
        let client = BridgeHarness.Client(connection: ConnectionID(1), installationId: UUID(), epoch: "epoch-1", kind: .desktopApp)
        harness.send(client, type: "hello", payload: #"{"installationId":"\#(client.installationId.uuidString)","connectorKind":"desktopApp","adapterVersions":{"claude-desktop":"0.1.0"}}"#)
        let list = (entries ?? [entry("aaaa-0", "Alpha")]).joined(separator: ",")
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(list)]}"#)
        return (harness, client)
    }

    @Test("entries become routes with no browser fields and no profile")
    func rows() throws {
        let (harness, client) = connected()
        #expect(client.connectorId.hasPrefix("desktopApp-"))
        let row = try #require(harness.coordinator.rows().first)
        #expect(row.provider == "claude-desktop" && row.title == "Alpha" && row.profileAlias == nil)
        #expect(row.tabId == nil && row.windowId == nil && row.url == nil)
        #expect(harness.coordinator.connectorSummaries().first?.providerType == .desktopApp)
        #expect(harness.coordinator.connectorSummaries().first?.routeCount == 1)
    }

    @Test("a new snapshot replaces the list: entries not in it are gone, new ones appear")
    func replacement() {
        var (harness, client) = connected([entry("aaaa-0", "Alpha"), entry("bbbb-0", "Beta")])
        #expect(harness.coordinator.rows().count == 2)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entry("bbbb-0", "Beta")),\#(entry("cccc-0", "Gamma"))]}"#)
        #expect(Set(harness.coordinator.rows().map(\.title)) == ["Beta", "Gamma"])
    }

    @Test("an unchanged entry keeps its revision, a moved one does not")
    func revisions() throws {
        var (harness, client) = connected([entry("aaaa-0", "Alpha")])
        let first = try #require(harness.coordinator.rows().first)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entry("aaaa-0", "Alpha"))]}"#)
        #expect(try #require(harness.coordinator.rows().first).revision == first.revision)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entry("aaaa-0", "Alpha", ordinal: 3))]}"#)
        #expect(try #require(harness.coordinator.rows().first).revision == first.revision + 1)
    }

    @Test("an app connector may not report browser tabs or incremental updates")
    func scopeIsEnforced() throws {
        var (harness, client) = connected()
        let tab = #"{"tabId":1,"windowId":1,"provider":"claude","providerConversationId":"x","title":"T","canonicalUrl":"https://claude.ai/chat/x"}"#
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[\#(tab)]}"#)
        #expect(try harness.errorCodes(to: client.connection).contains(.unauthorized))
        #expect(harness.wasClosed(client.connection))
    }

    @Test("a provider that hello did not declare is refused, and duplicate ids or odd bundles are malformed")
    func validation() throws {
        var (harness, client) = connected()
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entry("zzzz-0", "Z", provider: "chatgpt-desktop"))]}"#)
        #expect(try harness.errorCodes(to: client.connection) == [.unauthorized])

        var duplicate = connected().0
        let twin = BridgeHarness.Client(connection: ConnectionID(2), installationId: UUID(), epoch: "e", kind: .desktopApp)
        duplicate.send(twin, type: "hello", payload: #"{"installationId":"\#(twin.installationId.uuidString)","connectorKind":"desktopApp","adapterVersions":{"claude-desktop":"0.1.0"}}"#)
        duplicate.send(twin, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entry("a-0", "A")),\#(entry("a-0", "B"))]}"#)
        #expect(try duplicate.errorCodes(to: twin.connection) == [.malformed])
    }

    @Test("activation carries the title and position to verify, and an answer completes it")
    func activation() throws {
        var (harness, client) = connected([entry("aaaa-1", "Test", ordinal: 1)])
        let row = try #require(harness.coordinator.rows().first)
        let start = harness.coordinator.requestActivation(destinationId: row.destinationId, expectedRevision: row.revision, now: harness.now)
        guard case .dispatched(let requestId, let outbound) = start else { Issue.record("got \(start)"); return }
        harness.record(BridgeResult(outbound: outbound))
        guard case .activateRequest(let payload) = try #require(try harness.messages(to: client.connection).last).body else { Issue.record("no request"); return }
        #expect(payload.app == AppTarget(bundleId: claude, expectedTitle: "Test", ordinal: 1))
        #expect(payload.tabId == nil && payload.editor == nil)
        let answer = #"{"requestId":"\#(requestId)","destinationId":"\#(row.destinationId)","destinationRevision":\#(row.revision),"outcome":"activated"}"#
        let result = harness.send(client, type: "activate.result", payload: answer)
        #expect(result.events.contains { if case .activation(let outcome) = $0 { outcome.outcome == .activated } else { false } })
    }

    @Test("the registry accepts only the two known apps, with a bounded title and position")
    func locatorPolicy() {
        let policy = LocatorPolicy()
        func locator(_ bundle: String, _ title: String = "T", _ ordinal: Int = 0) -> Locator {
            .appEntry(AppEntryLocator(bundleId: bundle, title: title, ordinal: ordinal))
        }
        #expect(throws: Never.self) { try policy.validate(locator("com.anthropic.claudefordesktop")) }
        #expect(throws: Never.self) { try policy.validate(locator("com.openai.codex")) }
        #expect(throws: LocatorRejection.unsupportedApp("com.example.App")) { try policy.validate(locator("com.example.App")) }
        #expect(throws: LocatorRejection.invalidAppEntry) { try policy.validate(locator("com.openai.codex", "")) }
        #expect(throws: LocatorRejection.invalidAppEntry) { try policy.validate(locator("com.openai.codex", "T", 200)) }
    }

    private let vscode = "com.microsoft.VSCode"

    private func threadEntry(_ id: String, _ title: String, path: String) -> String {
        #"{"provider":"codex","providerConversationId":"\#(id)","title":"\#(title)","bundleId":"\#(vscode)","ordinal":0,"workspacePath":"\#(path)"}"#
    }

    private func threadConnector(_ entries: [String]) -> (BridgeHarness, BridgeHarness.Client) {
        var harness = BridgeHarness()
        let client = BridgeHarness.Client(connection: ConnectionID(1), installationId: UUID(), epoch: "epoch-1", kind: .desktopApp)
        harness.send(client, type: "hello", payload: #"{"installationId":"\#(client.installationId.uuidString)","connectorKind":"desktopApp","adapterVersions":{"codex":"0.1.0"}}"#)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entries.joined(separator: ","))]}"#)
        return (harness, client)
    }

    @Test("a thread that records its project folder is named by that folder, in place of a profile")
    func projectNamesTheRow() throws {
        let (harness, _) = threadConnector([threadEntry("0199c2f4-aaaa", "Fix login", path: "/Users/example/Atlas")])
        let row = try #require(harness.coordinator.rows().first)
        #expect(row.provider == "codex" && row.profileAlias == "Atlas" && row.title == "Fix login")
    }

    @Test("opening such a thread first asks for the project's window to be brought forward")
    func threadActivationPreparesTheWindow() throws {
        var (harness, client) = threadConnector([threadEntry("0199c2f4-aaaa", "Fix login", path: "/Users/example/Atlas")])
        let row = try #require(harness.coordinator.rows().first)
        let start = harness.coordinator.requestActivation(destinationId: row.destinationId, expectedRevision: row.revision, now: harness.now)
        guard case .dispatchedAfterPreparation(_, let outbound, let preparation) = start else { Issue.record("got \(start)"); return }
        #expect(preparation == ActivationPreparation(bundleId: vscode, workspacePath: "/Users/example/Atlas"))
        harness.record(BridgeResult(outbound: outbound))
        guard case .activateRequest(let payload) = try #require(try harness.messages(to: client.connection).last).body else { Issue.record("no request"); return }
        #expect(payload.expectedConversationId == "0199c2f4-aaaa" && payload.app?.bundleId == vscode)
    }

    @Test("a folder path that climbs out with .. is malformed, and the registry accepts only plain absolute paths")
    func pathsAreChecked() throws {
        var (harness, client) = threadConnector([])
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(threadEntry("x-1", "T", path: "/Users/example/../etc"))]}"#)
        #expect(try harness.errorCodes(to: client.connection) == [.malformed])
        let policy = LocatorPolicy()
        #expect(throws: LocatorRejection.invalidWorkspacePath) {
            try policy.validate(.appEntry(AppEntryLocator(bundleId: vscode, title: "T", ordinal: 0, workspacePath: "relative/path")))
        }
        #expect(throws: Never.self) {
            try policy.validate(.appEntry(AppEntryLocator(bundleId: vscode, title: "T", ordinal: 0, workspacePath: "/Users/example/Atlas")))
        }
    }
}
