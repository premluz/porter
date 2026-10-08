import Foundation
import Testing
@testable import ConversationCore

@Suite("Route identity survives a tab briefly missing from the tab list")
struct BridgeContinuityTests {
    private func connected(chat: String = "chat-a") -> (BridgeHarness, BridgeHarness.Client) {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client, alias: "Personal")
        harness.snapshot(client, tabs: [(42, 7, chat, "Release plan")])
        return (harness, client)
    }

    @Test("a tab that drops out of one snapshot and returns keeps its route ID with a newer revision")
    func sameTabSameChatKeepsId() throws {
        var (harness, client) = connected()
        let before = try #require(harness.coordinator.rows().first)
        harness.snapshot(client, tabs: [])
        #expect(harness.coordinator.rows().isEmpty)
        harness.snapshot(client, tabs: [(42, 7, "chat-a", "Renamed plan")])
        let after = try #require(harness.coordinator.rows().first)
        #expect(after.destinationId == before.destinationId)
        #expect(after.conversationId == before.conversationId)
        #expect(after.revision > before.revision)
        #expect(after.title == "Renamed plan")
    }

    @Test("a selection made before the drop-out is refused as changed, never silently reused")
    func oldRevisionRefused() throws {
        var (harness, client) = connected()
        let before = try #require(harness.coordinator.rows().first)
        harness.snapshot(client, tabs: [])
        harness.snapshot(client, tabs: [(42, 7, "chat-a", "Release plan")])
        let outcome = harness.coordinator.requestActivation(
            destinationId: before.destinationId, expectedRevision: before.revision, now: harness.now
        )
        guard case .refused(let result) = outcome else { Issue.record("expected refusal"); return }
        #expect(result.outcome == .targetChanged)
    }

    @Test("while the tab is missing, activation reports it gone")
    func missingTabIsGone() throws {
        var (harness, client) = connected()
        let before = try #require(harness.coordinator.rows().first)
        harness.snapshot(client, tabs: [])
        guard case .refused(let result) = harness.coordinator.requestActivation(
            destinationId: before.destinationId, expectedRevision: before.revision, now: harness.now
        ) else { Issue.record("expected refusal"); return }
        #expect(result.outcome == .targetGone)
    }

    @Test("the same tab number showing a different chat gets a new route ID")
    func differentChatGetsNewId() throws {
        var (harness, client) = connected()
        let before = try #require(harness.coordinator.rows().first)
        harness.snapshot(client, tabs: [])
        harness.snapshot(client, tabs: [(42, 7, "chat-b", "Other chat")])
        let after = try #require(harness.coordinator.rows().first)
        #expect(after.destinationId != before.destinationId)
        #expect(after.conversationId != before.conversationId)
    }

    @Test("a reconnect never reuses earlier route IDs")
    func reconnectStartsFresh() throws {
        var (harness, client) = connected()
        let before = try #require(harness.coordinator.rows().first)
        harness.snapshot(client, tabs: [])
        harness.record(harness.coordinator.disconnect(client.connection, now: harness.now))
        let restarted = BridgeHarness.Client(connection: ConnectionID(2), installationId: client.installationId, epoch: "epoch-2")
        harness.hello(restarted, alias: "Personal")
        harness.snapshot(restarted, tabs: [(42, 7, "chat-a", "Release plan")])
        let after = try #require(harness.coordinator.rows().first)
        #expect(after.destinationId != before.destinationId)
    }

    @Test("remembered routes are bounded")
    func bounded() throws {
        var (harness, client) = connected()
        for index in 0..<(BridgeCoordinator.maximumRememberedRoutes + 50) {
            harness.snapshot(client, tabs: [(1000 + index, 7, "c\(index)", "t")])
        }
        #expect(harness.coordinator.rememberedRouteCount <= BridgeCoordinator.maximumRememberedRoutes)
    }
}
