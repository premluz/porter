import Foundation
import Testing
@testable import ConversationCore

@Suite("Agent status from hook events")
struct AgentStatusTests {
    private let folder = "/Users/example/Porter"

    private func window(
        tabs: [(id: String, title: String, path: String, column: Int, index: Int)]? = nil, provider: String = "claude-code"
    ) -> (BridgeHarness, BridgeHarness.Client) {
        var harness = BridgeHarness()
        let client = BridgeHarness.editor(1)
        harness.helloEditor(client, providers: ["claude-code", "codex"])
        harness.editorSnapshot(client, tabs: tabs ?? [("aaaa1111", "Release plan", folder, 1, 0)], provider: provider)
        return (harness, client)
    }

    private func event(
        _ name: String, session: String = "s1", cwd: String = "/Users/example/Porter",
        notification: String? = nil, entrypoint: String? = AgentEvent.vscodeEntrypoint
    ) -> AgentEvent {
        AgentEvent(event: name, sessionId: session, cwd: cwd, notificationType: notification, entrypoint: entrypoint)
    }

    private func status(_ harness: BridgeHarness, at now: Date? = nil) -> DestinationStatus? {
        guard let route = harness.coordinator.rows().first else { return nil }
        return harness.coordinator.agentStatuses(now: now ?? harness.now)[route.destinationId]
    }

    private func send(_ harness: inout BridgeHarness, _ agent: AgentEvent) -> BridgeResult {
        harness.coordinator.recordAgentEvent(agent, now: harness.now)
    }

    @Test("a prompt means working, a tool call keeps it working, finishing means idle")
    func lifecycle() {
        var (harness, _) = window()
        _ = send(&harness, event("SessionStart"))
        #expect(status(harness)?.display == .idle)
        _ = send(&harness, event("UserPromptSubmit"))
        #expect(status(harness)?.display == .working && status(harness)?.freshness == .fresh)
        _ = send(&harness, event("PreToolUse"))
        _ = send(&harness, event("PostToolUse"))
        #expect(status(harness)?.display == .working)
        _ = send(&harness, event("Stop"))
        #expect(status(harness)?.display == .idle)
    }

    @Test("a permission prompt or a question means needs you; resuming work clears it; an idle prompt is just idle")
    func needsYou() {
        var (harness, _) = window()
        _ = send(&harness, event("UserPromptSubmit"))
        for type in ["permission_prompt", "elicitation_dialog", "agent_needs_input"] {
            _ = send(&harness, event("Notification", notification: type))
            #expect(status(harness)?.display == .needsUser, "\(type)")
            _ = send(&harness, event("PreToolUse"))
            #expect(status(harness)?.display == .working, "\(type) resolved")
        }
        _ = send(&harness, event("Notification", notification: "idle_prompt"))
        #expect(status(harness)?.display == .idle)
    }

    @Test("notifications that say nothing about the agent's state change nothing")
    func irrelevantNotifications() {
        var (harness, _) = window()
        _ = send(&harness, event("UserPromptSubmit"))
        for type in ["auth_success", "quota_auto_resume_fired", "something_new"] {
            let result = send(&harness, event("Notification", notification: type))
            #expect(result.events.isEmpty, "\(type)")
        }
        #expect(status(harness)?.display == .working)
    }

    @Test("ending the session removes its status instead of leaving the last word standing")
    func sessionEnd() {
        var (harness, _) = window()
        _ = send(&harness, event("UserPromptSubmit"))
        _ = send(&harness, event("SessionEnd"))
        #expect(status(harness) == nil)
        #expect(send(&harness, event("SessionEnd")).events.isEmpty)
    }

    @Test("only a real change is announced, so the panel is not redrawn for repeated tool calls")
    func announcesChanges() {
        var (harness, _) = window()
        #expect(send(&harness, event("UserPromptSubmit")).events == [.statusChanged])
        #expect(send(&harness, event("PreToolUse")).events.isEmpty)
        #expect(send(&harness, event("Stop")).events == [.statusChanged])
    }

    @Test("a status goes stale instead of reading as live: after half an hour, or when the window disconnects")
    func staleness() {
        var (harness, client) = window()
        _ = send(&harness, event("UserPromptSubmit"))
        let later = harness.now.addingTimeInterval(BridgeCoordinator.agentStatusLifetime + 1)
        let expired = status(harness, at: later)
        #expect(expired?.display == .unknown && expired?.freshness == .stale)
        #expect(expired?.lastKnown?.activity == .working)
        harness.record(harness.coordinator.disconnect(client.connection, now: harness.now))
        let offline = status(harness)
        #expect(offline?.display == .unknown && offline?.freshness == .stale)
    }

    @Test("only sessions started from VS Code count; a terminal session in the same folder is ignored")
    func entrypointFilter() {
        var (harness, _) = window()
        _ = send(&harness, event("UserPromptSubmit", entrypoint: "cli"))
        #expect(status(harness) == nil)
        _ = send(&harness, event("UserPromptSubmit", entrypoint: nil))
        #expect(status(harness) == nil)
        _ = send(&harness, event("UserPromptSubmit", session: "s2"))
        #expect(status(harness)?.display == .working)
    }

    @Test("two sessions, or two tabs, in one window are ambiguous, so status stays unknown")
    func ambiguity() {
        var (harness, _) = window()
        _ = send(&harness, event("UserPromptSubmit", session: "s1"))
        _ = send(&harness, event("UserPromptSubmit", session: "s2"))
        #expect(status(harness) == nil)
        var (twoTabs, _) = window(tabs: [("aaaa1111", "One", folder, 1, 0), ("bbbb2222", "Two", folder, 1, 1)])
        _ = send(&twoTabs, event("UserPromptSubmit"))
        #expect(twoTabs.coordinator.agentStatuses(now: twoTabs.now).isEmpty)
    }

    @Test("a session working in a sub-folder belongs to the window that contains it, and the deepest window wins")
    func folderMatching() {
        var harness = BridgeHarness()
        let outer = BridgeHarness.editor(1)
        let inner = BridgeHarness.editor(2)
        harness.helloEditor(outer, folder: "Porter")
        harness.helloEditor(inner, folder: "app")
        harness.editorSnapshot(outer, tabs: [("aaaa1111", "Outer", folder, 1, 0)])
        harness.editorSnapshot(inner, tabs: [("bbbb2222", "Inner", folder + "/apps/mac", 1, 0)])
        _ = send(&harness, event("UserPromptSubmit", cwd: folder + "/apps/mac/Sources"))
        let rows = Dictionary(uniqueKeysWithValues: harness.coordinator.rows().map { ($0.title, $0.destinationId) })
        let statuses = harness.coordinator.agentStatuses(now: harness.now)
        #expect(statuses[rows["Inner"] ?? UUID()]?.display == .working)
        #expect(statuses[rows["Outer"] ?? UUID()] == nil)
        _ = send(&harness, event("UserPromptSubmit", session: "s9", cwd: "/Users/example/Porter-other"))
        #expect(harness.coordinator.agentStatuses(now: harness.now)[rows["Outer"] ?? UUID()] == nil)
    }

    @Test("a Codex tab never receives a Claude Code session's status")
    func providerBoundary() {
        var (harness, _) = window(provider: "codex")
        _ = send(&harness, event("UserPromptSubmit"))
        #expect(harness.coordinator.agentStatuses(now: harness.now).isEmpty)
    }

    @Test("events are checked: other sources, unknown events, relative paths and odd IDs are refused")
    func validation() {
        let good = event("Stop")
        #expect(throws: Never.self) { try good.validated() }
        #expect(throws: AgentEventRejection.unsupportedSource("other")) { try AgentEvent(source: "other", event: "Stop", sessionId: "s", cwd: "/p").validated() }
        #expect(throws: AgentEventRejection.unsupportedEvent("Whatever")) { try event("Whatever").validated() }
        #expect(throws: AgentEventRejection.invalidField("cwd")) { try event("Stop", cwd: "relative").validated() }
        #expect(throws: AgentEventRejection.invalidField("cwd")) { try event("Stop", cwd: "/a/../b").validated() }
        #expect(throws: AgentEventRejection.invalidField("sessionId")) { try event("Stop", session: "has space").validated() }
        #expect(throws: AgentEventRejection.invalidField("entrypoint")) { try event("Stop", entrypoint: "a b").validated() }
        #expect(throws: AgentEventRejection.invalidField("notificationType")) { try event("Notification", notification: String(repeating: "x", count: 65)).validated() }
    }

    @Test("an event carries nothing beyond its whitelisted fields, so prompts and tool input cannot be kept")
    func privacy() throws {
        let data = try JSONEncoder().encode(event("UserPromptSubmit", notification: nil))
        let keys = Set(try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]).keys)
        #expect(keys.isSubset(of: ["source", "event", "sessionId", "cwd", "notificationType", "entrypoint"]))
    }

    @Test("the table of remembered sessions is bounded")
    func bounded() {
        var (harness, _) = window()
        for index in 0..<(BridgeCoordinator.maximumAgentSessions + 50) {
            _ = send(&harness, event("UserPromptSubmit", session: "session-\(index)"))
        }
        #expect(harness.coordinator.agentSessionCount <= BridgeCoordinator.maximumAgentSessions)
    }
}
