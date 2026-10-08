import Foundation

struct AgentSession: Sendable, Equatable {
    let cwd: String
    let entrypoint: String?
    let activity: Activity
    let attention: Attention
    let receivedAt: Date
    let sequence: Int
}

extension BridgeCoordinator {
    /// A hook event only fires between a start and a stop, so a state stays true until the next event
    /// rather than for the short lifetime a polled signal would have. Half an hour covers a long tool
    /// run; a session that dies without a final event then reads as stale, not as working forever.
    static let agentStatusLifetime: TimeInterval = 30 * 60
    static let maximumAgentSessions = 200
    static let agentAdapterVersion = "0.1.0"
    static let agentConnectionEpoch = "hook"

    /// Records an event and reports whether anything visible could have changed.
    public mutating func recordAgentEvent(_ event: AgentEvent, now: Date) -> BridgeResult {
        agentSequence += 1
        switch event.transition {
        case .ignore:
            return BridgeResult()
        case .clear:
            return agentSessions.removeValue(forKey: event.sessionId) == nil ? BridgeResult() : BridgeResult(events: [.statusChanged])
        case .set(let activity, let attention):
            let next = AgentSession(
                cwd: event.cwd, entrypoint: event.entrypoint, activity: activity, attention: attention,
                receivedAt: now, sequence: agentSequence
            )
            let previous = agentSessions.updateValue(next, forKey: event.sessionId)
            pruneAgentSessions()
            guard previous?.activity != activity || previous?.attention != attention else { return BridgeResult() }
            return BridgeResult(events: [.statusChanged])
        }
    }

    private mutating func pruneAgentSessions() {
        guard agentSessions.count > Self.maximumAgentSessions else { return }
        let keep = agentSessions.sorted { $0.value.sequence > $1.value.sequence }.prefix(Self.maximumAgentSessions)
        agentSessions = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
    }

    /// Status for Claude Code tabs, only where it can be attributed with certainty: the session was
    /// started from this editor, lives in this window's folder, and there is exactly one such session
    /// and one such tab. Anything less stays Unknown, because a wrong "working" is worse than none.
    public func agentStatuses(now: Date) -> [UUID: DestinationStatus] {
        let routes = claudeCodeRoutes()
        let workspaces = Set(routes.map(\.workspacePath))
        var sessionsByWorkspace: [String: [AgentSession]] = [:]
        for session in agentSessions.values where session.entrypoint == AgentEvent.vscodeEntrypoint {
            guard let workspace = Self.longestMatch(of: session.cwd, in: workspaces) else { continue }
            sessionsByWorkspace[workspace, default: []].append(session)
        }
        var projection = StatusProjection(policy: FreshnessPolicy(maximumLifetime: Self.agentStatusLifetime))
        var reachability: [UUID: Reachability] = [:]
        let routesByWorkspace = Dictionary(grouping: routes, by: \.workspacePath)
        for (workspace, tabs) in routesByWorkspace {
            guard tabs.count == 1, let route = tabs.first, let sessions = sessionsByWorkspace[workspace], sessions.count == 1,
                  let session = sessions.first else { continue }
            projection.record(observation(for: route.destinationId, from: session))
            reachability[route.destinationId] = route.reachability
        }
        return Dictionary(uniqueKeysWithValues: reachability.map { id, reach in
            (id, projection.status(for: id, reachability: reach, now: now))
        })
    }

    private struct ClaudeCodeRoute {
        let destinationId: UUID
        let workspacePath: String
        let reachability: Reachability
    }

    private func claudeCodeRoutes() -> [ClaudeCodeRoute] {
        registry.allDestinations().compactMap { destination in
            guard case .editorTab(let editor) = destination.locator,
                  conversations[destination.conversationId]?.provider == AgentEvent.claudeCodeSource,
                  let connectorId = destination.connectorId, let connector = connectors[connectorId] else { return nil }
            let live = connectionByInstallation[connector.installationId] != nil
            return ClaudeCodeRoute(
                destinationId: destination.id, workspacePath: editor.workspacePath, reachability: live ? .connected : .disconnected
            )
        }
    }

    /// The deepest folder that contains the path, so a window on a sub-folder claims its own sessions.
    private static func longestMatch(of path: String, in folders: Set<String>) -> String? {
        folders.filter { path == $0 || path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }.max { $0.count < $1.count }
    }

    private func observation(for destinationId: UUID, from session: AgentSession) -> StatusObservation {
        StatusObservation(
            id: UUID(), destinationId: destinationId, activity: session.activity, attention: session.attention,
            evidenceKind: .providerEvent, observedAt: session.receivedAt, receivedAt: session.receivedAt,
            expiresAt: session.receivedAt.addingTimeInterval(Self.agentStatusLifetime), sequence: session.sequence,
            connectionEpoch: Self.agentConnectionEpoch, adapterVersion: Self.agentAdapterVersion
        )
    }
}
