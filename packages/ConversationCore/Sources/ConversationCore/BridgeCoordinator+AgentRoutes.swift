import Foundation

extension BridgeCoordinator {
    /// A session bound to a tab is that tab's (the latest one, if a tab was reused). What is left over is paired only
    /// when exactly one tab and one session remain, so a leftover is never guessed at.
    func pairings(
        tabs: [ClaudeCodeRoute], sessions: [(id: String, session: AgentSession)]
    ) -> [(ClaudeCodeRoute, AgentSession)] {
        var pairs: [(ClaudeCodeRoute, AgentSession)] = []
        var freeTabs = tabs
        var unbound: [AgentSession] = []
        var ownersByTab: [String: [AgentSession]] = [:]
        for (id, session) in sessions {
            if let binding = agentBindings[id], tabs.contains(where: { $0.conversationId == binding.conversationId }) {
                ownersByTab[binding.conversationId, default: []].append(session)
            } else {
                unbound.append(session)
            }
        }
        for (conversationId, owners) in ownersByTab {
            guard let route = tabs.first(where: { $0.conversationId == conversationId }),
                  let latest = owners.max(by: { $0.sequence < $1.sequence }) else { continue }
            pairs.append((route, latest))
            freeTabs.removeAll { $0.conversationId == conversationId }
        }
        if freeTabs.count == 1, unbound.count == 1, let tab = freeTabs.first, let session = unbound.first { pairs.append((tab, session)) }
        return pairs
    }

    struct ClaudeCodeRoute {
        let destinationId: UUID
        /// The connector-derived id of the tab, stable across runs.
        let conversationId: String
        let conversationKey: UUID
        let workspacePath: String
        let reachability: Reachability
    }

    func claudeCodeRoutes() -> [ClaudeCodeRoute] {
        registry.allDestinations().compactMap { destination in
            guard case .editorTab(let editor) = destination.locator,
                  let conversation = conversations[destination.conversationId], conversation.provider == AgentEvent.claudeCodeSource,
                  let tabId = conversation.providerConversationId,
                  let connectorId = destination.connectorId, let connector = connectors[connectorId] else { return nil }
            let live = connectionByInstallation[connector.installationId] != nil
            return ClaudeCodeRoute(
                destinationId: destination.id, conversationId: tabId, conversationKey: destination.conversationId,
                workspacePath: editor.workspacePath, reachability: live ? .connected : .disconnected
            )
        }
    }

}
