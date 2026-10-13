import Foundation
import Testing
@testable import ConversationCore

@Suite("Structural turn end evidence")
struct TurnEndTests {
    private func editor() -> BridgeHarness {
        var harness = BridgeHarness()
        let client = BridgeHarness.editor(1)
        harness.helloEditor(client, providers: ["claude-code"])
        harness.editorSnapshot(client, tabs: [("thread-a", "Task", "/Users/example/Porter", 1, 0)])
        return harness
    }

    private func event(_ name: String) -> AgentEvent {
        AgentEvent(event: name, sessionId: "session", cwd: "/Users/example/Porter", entrypoint: AgentEvent.vscodeEntrypoint)
    }

    private func status(_ harness: BridgeHarness) throws -> DestinationStatus? {
        let route = try #require(harness.coordinator.rows().first)
        return harness.coordinator.agentStatuses(now: harness.now)[route.destinationId]
    }

    @Test func stopSuppliesTimestampAndSessionEndDoesNot() throws {
        var harness = editor()
        _ = harness.coordinator.recordAgentEvent(event("UserPromptSubmit"), now: harness.now)
        #expect(try status(harness)?.turnEnd == nil)
        let end = harness.now.addingTimeInterval(1)
        _ = harness.coordinator.recordAgentEvent(event("Stop"), now: end)
        #expect(try status(harness)?.turnEnd == TurnEnd(at: end, kind: .completed))
        _ = harness.coordinator.recordAgentEvent(event("SessionEnd"), now: end)
        #expect(try status(harness)?.turnEnd == nil)
    }

    @Test func lapseAndStartupDoNotSupplyEnd() throws {
        var harness = editor()
        _ = harness.coordinator.recordAgentEvent(event("SessionStart"), now: harness.now)
        #expect(try status(harness)?.turnEnd == nil)
        _ = harness.coordinator.recordAgentEvent(event("UserPromptSubmit"), now: harness.now)
        let route = try #require(harness.coordinator.rows().first)
        let late = harness.now.addingTimeInterval(BridgeCoordinator.agentStatusLifetime + 1)
        let stale = harness.coordinator.agentStatuses(now: late)[route.destinationId]
        #expect(stale?.display == .unknown && stale?.turnEnd == nil)
    }

    @Test(arguments: [TurnEndKind.completed, .interrupted])
    func appReportRoundTrip(kind: TurnEndKind) throws {
        let entry = AppEntryReport(provider: "codex", providerConversationId: "thread-a", title: "Task",
            bundleId: "com.openai.codex", ordinal: 0, lastTurnEndedAt: Date(), lastTurnEndKind: kind)
        let encoded = try ContractCoding.encoder().encode(entry)
        let decoded = try ContractCoding.decoder().decode(AppEntryReport.self, from: encoded)
        #expect(decoded.lastTurnEndKind == kind)
        #expect(decoded.lastTurnEndedAt != nil)
        var coordinator = BridgeCoordinator(deviceId: UUID())
        let id = UUID()
        let first = coordinator.setTurnEnd(id, entry: decoded)
        let repeated = coordinator.setTurnEnd(id, entry: decoded)
        #expect(first)
        #expect(!repeated)
        #expect(coordinator.appTurnEnds[id]?.kind == kind)
    }

    @Test func incompleteEndIsRejected() {
        let entry = AppEntryReport(provider: "codex", providerConversationId: "thread-a", title: "Task",
            bundleId: "com.openai.codex", ordinal: 0, lastTurnEndedAt: Date())
        #expect(throws: EnvelopeRejection.self) { try BridgeValidation.validate(entry) }
    }

    @Test func appEndIsExposedOnItsRouteAndNotInventedOnWithdrawal() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.Client(connection: ConnectionID(1), installationId: UUID(), epoch: "turn", kind: .desktopApp)
        harness.send(client, type: "hello", payload: #"{"installationId":"\#(client.installationId.uuidString)","connectorKind":"desktopApp","adapterVersions":{"codex":"0.1.0"}}"#)
        let report = AppEntryReport(provider: "codex", providerConversationId: "thread", title: "Task",
            bundleId: "com.openai.codex", ordinal: 0, lastTurnEndedAt: harness.now, lastTurnEndKind: .interrupted)
        let data = try ContractCoding.encoder().encode(InventorySnapshotPayload(tabs: [], appEntries: [report]))
        harness.send(client, type: "inventory.snapshot", payload: String(decoding: data, as: UTF8.self))
        let route = try #require(harness.coordinator.rows().first)
        let status = harness.coordinator.appStatuses(now: harness.now)[route.destinationId]
        #expect(status?.turnEnd == TurnEnd(at: harness.now, kind: .interrupted))
        #expect(status?.display == .idle)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"appEntries":[]}"#)
        #expect(harness.coordinator.appTurnEnds.isEmpty)
    }
}
