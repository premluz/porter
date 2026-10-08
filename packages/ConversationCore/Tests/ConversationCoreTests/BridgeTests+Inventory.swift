import Foundation
import Testing
@testable import ConversationCore

@Suite("Two profiles, identical titles (TEST-001) and moving targets (TEST-002)")
struct BridgeInventoryTests {
    private func twoProfiles() -> (BridgeHarness, BridgeHarness.Client, BridgeHarness.Client) {
        var harness = BridgeHarness()
        let personal = BridgeHarness.client(1)
        let work = BridgeHarness.client(2)
        harness.hello(personal, alias: "Personal")
        harness.hello(work, alias: "Work")
        harness.snapshot(personal, tabs: [(42, 7, "chat-a", "Release plan")])
        harness.snapshot(work, tabs: [(42, 3, "chat-a", "Release plan")])
        return (harness, personal, work)
    }

    @Test("identical titles, ids and tab numbers in two profiles stay two distinct routes")
    func identicalTitlesStayDistinct() {
        let (harness, _, _) = twoProfiles()
        let rows = harness.coordinator.rows()
        #expect(rows.count == 2)
        #expect(Set(rows.map(\.conversationId)).count == 2)
        #expect(Set(rows.map(\.destinationId)).count == 2)
        #expect(rows.map(\.profileAlias) == ["Personal", "Work"])
        #expect(rows.allSatisfy { $0.title == "Release plan" && $0.routeCount == 1 })
    }

    @Test("duplicate tabs of one conversation in one profile are two routes the user must choose between")
    func duplicateTabsAreAmbiguous() {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client, alias: "Personal")
        harness.snapshot(client, tabs: [(1, 1, "chat-a", "Plan"), (2, 1, "chat-a", "Plan")])
        let rows = harness.coordinator.rows()
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.routeCount == 2 })
    }

    @Test("activation goes only to the connector that owns the chosen destination")
    func activationRoutedToOwner() throws {
        var (harness, personal, work) = twoProfiles()
        let target = try #require(harness.coordinator.rows().first { $0.profileAlias == "Work" })
        let start = harness.coordinator.requestActivation(destinationId: target.destinationId, expectedRevision: target.revision, now: harness.now)
        guard case .dispatched(_, let outbound) = start else { Issue.record("not dispatched: \(start)"); return }
        harness.record(BridgeResult(outbound: outbound))
        #expect(try harness.messages(to: personal.connection).allSatisfy { $0.header.type != .activateRequest })
        let request = try #require(try harness.messages(to: work.connection).last)
        guard case .activateRequest(let payload) = request.body else { Issue.record("no request"); return }
        #expect(payload.tabId == 42 && payload.windowId == 3)
        #expect(payload.expectedConversationId == "chat-a")
    }

    @Test("a successful acknowledgment completes the request; an unrelated one is refused")
    func acknowledgment() throws {
        var (harness, _, work) = twoProfiles()
        let target = try #require(harness.coordinator.rows().first { $0.profileAlias == "Work" })
        guard case .dispatched(let requestId, _) = harness.coordinator.requestActivation(
            destinationId: target.destinationId, expectedRevision: target.revision, now: harness.now
        ) else { Issue.record("not dispatched"); return }
        let stray = #"{"requestId":"\#(UUID())","destinationId":"\#(target.destinationId)","destinationRevision":\#(target.revision),"outcome":"activated"}"#
        harness.send(work, type: "activate.result", payload: stray)
        #expect(!harness.events.contains { if case .activation = $0 { true } else { false } })
        let real = #"{"requestId":"\#(requestId)","destinationId":"\#(target.destinationId)","destinationRevision":\#(target.revision),"outcome":"activated"}"#
        harness.send(work, type: "activate.result", payload: real)
        #expect(harness.events.contains(.activation(ActivationResult(
            requestId: requestId, destinationId: target.destinationId, destinationRevision: target.revision, outcome: .activated
        ))))
    }

    @Test("a closed tab is gone, and a moved or renamed route is refused, never retargeted")
    func closedAndChangedTargets() throws {
        var (harness, personal, _) = twoProfiles()
        let target = try #require(harness.coordinator.rows().first { $0.profileAlias == "Personal" })
        harness.snapshot(personal, tabs: [(42, 7, "chat-b", "Other chat")])
        let changed = harness.coordinator.requestActivation(destinationId: target.destinationId, expectedRevision: target.revision, now: harness.now)
        guard case .refused(let result) = changed else { Issue.record("expected refusal"); return }
        #expect(result.outcome == .targetChanged)
        harness.send(personal, type: "destination.remove", payload: #"{"tabId":42}"#)
        let gone = harness.coordinator.requestActivation(destinationId: target.destinationId, expectedRevision: target.revision, now: harness.now)
        guard case .refused(let goneResult) = gone else { Issue.record("expected refusal"); return }
        #expect(goneResult.outcome == .targetGone)
    }

    @Test("only a real change is reported as an inventory change")
    func inventoryEventsOnlyOnChange() {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client)
        func changes() -> Int { harness.events.filter { if case .inventoryChanged = $0 { true } else { false } }.count }
        harness.snapshot(client, tabs: [(1, 1, "chat-a", "Plan")])
        #expect(changes() == 1)
        harness.snapshot(client, tabs: [(1, 1, "chat-a", "Plan")])
        #expect(changes() == 1)
        harness.snapshot(client, tabs: [(1, 1, "chat-a", "Plan"), (2, 1, "chat-b", "Other")])
        #expect(changes() == 2)
        harness.snapshot(client, tabs: [])
        #expect(changes() == 4)
    }

    @Test("an identical snapshot does not change revisions")
    func identicalSnapshotKeepsRevision() {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client)
        harness.snapshot(client, tabs: [(1, 1, "chat-a", "Plan")])
        let before = harness.coordinator.rows()
        harness.snapshot(client, tabs: [(1, 1, "chat-a", "Plan")])
        #expect(harness.coordinator.rows() == before)
    }

    @Test("an unanswered request times out rather than guessing; a late answer is not accepted")
    func timeout() throws {
        var (harness, _, work) = twoProfiles()
        let target = try #require(harness.coordinator.rows().first { $0.profileAlias == "Work" })
        guard case .dispatched(let requestId, _) = harness.coordinator.requestActivation(
            destinationId: target.destinationId, expectedRevision: target.revision, now: harness.now
        ) else { Issue.record("not dispatched"); return }
        let swept = harness.coordinator.sweep(now: harness.now.addingTimeInterval(6))
        #expect(swept.events.contains { if case .activation(let r) = $0 { r.outcome == .timeout } else { false } })
        let late = #"{"requestId":"\#(requestId)","destinationId":"\#(target.destinationId)","destinationRevision":\#(target.revision),"outcome":"activated"}"#
        harness.send(work, type: "activate.result", payload: late)
        #expect(!harness.events.contains { if case .activation(let r) = $0 { r.outcome == .activated } else { false } })
    }

    @Test("disconnect marks routes disconnected and refuses activation; reconnect starts clean")
    func disconnectAndReconnect() throws {
        var (harness, personal, _) = twoProfiles()
        let target = try #require(harness.coordinator.rows().first { $0.profileAlias == "Personal" })
        harness.record(harness.coordinator.disconnect(personal.connection, now: harness.now))
        #expect(harness.coordinator.rows().first { $0.profileAlias == "Personal" }?.reachability == .disconnected)
        guard case .refused(let refused) = harness.coordinator.requestActivation(
            destinationId: target.destinationId, expectedRevision: target.revision, now: harness.now
        ) else { Issue.record("expected refusal"); return }
        #expect(refused.outcome == .connectorOffline)
        let restarted = BridgeHarness.Client(connection: ConnectionID(3), installationId: personal.installationId, epoch: "epoch-2")
        harness.hello(restarted, alias: "Personal")
        #expect(harness.coordinator.rows().filter { $0.profileAlias == "Personal" }.isEmpty)
        harness.snapshot(restarted, tabs: [(7, 2, "chat-a", "Release plan")])
        let again = try #require(harness.coordinator.rows().first { $0.profileAlias == "Personal" })
        #expect(again.reachability == .connected)
        #expect(again.destinationId != target.destinationId)
    }
}
