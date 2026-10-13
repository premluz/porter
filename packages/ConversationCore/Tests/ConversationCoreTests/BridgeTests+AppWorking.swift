import Foundation
import Testing
@testable import ConversationCore

@Suite("A desktop-app connector reporting a turn in progress")
struct BridgeAppWorkingTests {
    private func entry(_ id: String, working: Bool?) -> String {
        let flag = working.map { #","working":\#($0)"# } ?? ""
        return #"{"provider":"codex","providerConversationId":"\#(id)","title":"Thread \#(id)","bundleId":"com.openai.codex","ordinal":0\#(flag)}"#
    }

    private func connected(_ entries: [String]) -> (BridgeHarness, BridgeHarness.Client) {
        var harness = BridgeHarness()
        let client = BridgeHarness.Client(connection: ConnectionID(1), installationId: UUID(), epoch: "epoch-1", kind: .desktopApp)
        harness.send(client, type: "hello", payload: #"{"installationId":"\#(client.installationId.uuidString)","connectorKind":"desktopApp","adapterVersions":{"codex":"0.1.0"}}"#)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entries.joined(separator: ","))]}"#)
        return (harness, client)
    }

    private func display(_ harness: BridgeHarness, title: String, at offset: TimeInterval = 0) throws -> DisplayStatus? {
        let row = try #require(harness.coordinator.rows().first { $0.title == title })
        return harness.coordinator.appStatuses(now: harness.now.addingTimeInterval(offset))[row.destinationId]?.display
    }

    @Test("a route reported working is working, and one with no report has no status at all")
    func working() throws {
        let (harness, _) = connected([entry("a", working: true), entry("b", working: nil)])
        #expect(try display(harness, title: "Thread a") == .working)
        #expect(try display(harness, title: "Thread b") == nil)
    }

    @Test("the claim is withdrawn by the next report without it, and the change is announced")
    func withdrawn() throws {
        var (harness, client) = connected([entry("a", working: true)])
        let result = harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entry("a", working: nil))]}"#)
        #expect(result.events.contains(.statusChanged))
        #expect(try display(harness, title: "Thread a") == nil)
    }

    @Test("a repeated claim changes nothing visible, and a new one is announced")
    func repeated() throws {
        var (harness, client) = connected([entry("a", working: nil)])
        let started = harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entry("a", working: true))]}"#)
        #expect(started.events.contains(.statusChanged))
        let again = harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entry("a", working: true))]}"#)
        #expect(!again.events.contains(.statusChanged))
    }

    @Test("a claim that is not repeated lapses, so a silent connector never leaves a chat working for good")
    func lapses() throws {
        let (harness, _) = connected([entry("a", working: true)])
        #expect(try display(harness, title: "Thread a", at: BridgeCoordinator.appWorkingLifetime - 1) == .working)
        let late = try display(harness, title: "Thread a", at: BridgeCoordinator.appWorkingLifetime + 1)
        #expect(late == .unknown)
    }

    @Test("an entry that leaves the list takes its claim with it")
    func removed() throws {
        var (harness, client) = connected([entry("a", working: true), entry("b", working: nil)])
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[\#(entry("b", working: nil))]}"#)
        #expect(harness.coordinator.appStatuses(now: harness.now).isEmpty)
    }
}
