import Foundation

struct AgentSession: Sendable, Equatable {
    let cwd: String
    let entrypoint: String?
    let activity: Activity
    let attention: Attention
    let receivedAt: Date
    let sequence: Int
    let tty: String?
    let hostApp: String?
}

/// An agent running in a terminal, as its hook events show it.
public struct TerminalSession: Sendable, Equatable {
    public let sessionId: String
    public let cwd: String
    public let tty: String
    public let hostApp: String
    public let activity: Activity
    public let attention: Attention
    public let receivedAt: Date

    public init(sessionId: String, cwd: String, tty: String, hostApp: String, activity: Activity, attention: Attention, receivedAt: Date) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.tty = tty
        self.hostApp = hostApp
        self.activity = activity
        self.attention = attention
        self.receivedAt = receivedAt
    }
}

/// Which tab a session belongs to, kept by the tab's connector-derived conversation id (not the registry's route id,
/// which is new every run), so it survives Porter restarting. The tab in front when the prompt was submitted.
public struct AgentBinding: Codable, Sendable, Equatable {
    public let conversationId: String
    public let workspace: String
    public let boundAt: Date

    public init(conversationId: String, workspace: String, boundAt: Date) {
        self.conversationId = conversationId
        self.workspace = workspace
        self.boundAt = boundAt
    }
}

/// What the registry knows about one agent session, for diagnosing a status that does not show.
public struct AgentSessionSummary: Codable, Sendable, Equatable {
    public let shortId: String
    public let folder: String
    public let activity: String
    public let ageSeconds: Int
    /// The title of the tab it is bound to, or nil when it is not bound to one.
    public let boundTitle: String?
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
            var result = BridgeResult()
            if agentSessions.removeValue(forKey: event.sessionId) != nil { result.events.append(.statusChanged) }
            if agentBindings.removeValue(forKey: event.sessionId) != nil { result.events.append(.agentBindingsChanged) }
            return result
        case .set(let activity, let attention):
            let next = AgentSession(
                cwd: event.cwd, entrypoint: event.entrypoint, activity: activity, attention: attention,
                receivedAt: now, sequence: agentSequence, tty: event.tty ?? agentSessions[event.sessionId]?.tty,
                hostApp: event.hostApp ?? agentSessions[event.sessionId]?.hostApp
            )
            let previous = agentSessions.updateValue(next, forKey: event.sessionId)
            pruneAgentSessions()
            let bound = bindIfPossible(event, now: now)
            var result = BridgeResult()
            if previous?.activity != activity || previous?.attention != attention || bound { result.events.append(.statusChanged) }
            if bound { result.events.append(.agentBindingsChanged) }
            return result
        }
    }

    /// A session keeps the tab it was first seen in. It is chosen when a prompt is submitted, because the person
    /// typed in a tab that was in front: of this window's Claude Code tabs, the one that came to the front last.
    /// Anything unclear (no times from the connector, two tabs in front at once) binds nothing.
    private mutating func bindIfPossible(_ event: AgentEvent, now: Date) -> Bool {
        let routes = claudeCodeRoutes()
        if let kept = agentBindings[event.sessionId], routes.contains(where: { $0.conversationId == kept.conversationId }) { return false }
        guard event.event == "UserPromptSubmit", event.entrypoint == AgentEvent.vscodeEntrypoint,
              let workspace = Self.longestMatch(of: event.cwd, in: Set(routes.map(\.workspacePath))) else { return false }
        let stamped = routes.filter { $0.workspacePath == workspace }.compactMap { route in
            lastActive[route.destinationId].map { (route, $0) }
        }
        guard let newest = stamped.map(\.1).max() else { return false }
        let candidates = stamped.filter { $0.1 == newest }
        guard candidates.count == 1 else { return false }
        agentBindings[event.sessionId] = AgentBinding(conversationId: candidates[0].0.conversationId, workspace: workspace, boundAt: now)
        pruneAgentBindings(now: now)
        return true
    }

    static let agentBindingLifetime: TimeInterval = 7 * 86_400
    static let maximumAgentBindings = 200

    private mutating func pruneAgentBindings(now: Date) {
        agentBindings = agentBindings.filter { now.timeIntervalSince($0.value.boundAt) <= Self.agentBindingLifetime }
        guard agentBindings.count > Self.maximumAgentBindings else { return }
        let keep = agentBindings.sorted { $0.value.boundAt > $1.value.boundAt }.prefix(Self.maximumAgentBindings)
        agentBindings = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
    }

    /// Agents running in a terminal that have said which terminal they are in, newest first, while their last word is
    /// still within the status lifetime. A session started from VS Code's panel is not here: it has a tab.
    public func terminalSessions(now: Date) -> [TerminalSession] {
        agentSessions.compactMap { id, session -> TerminalSession? in
            guard session.entrypoint != AgentEvent.vscodeEntrypoint, let tty = session.tty, let host = session.hostApp,
                  now.timeIntervalSince(session.receivedAt) <= Self.agentStatusLifetime else { return nil }
            return TerminalSession(
                sessionId: id, cwd: session.cwd, tty: tty, hostApp: host, activity: session.activity,
                attention: session.attention, receivedAt: session.receivedAt
            )
        }.sorted { $0.receivedAt > $1.receivedAt }
    }

    /// The bindings to keep across a restart of Porter.
    public func exportedAgentBindings() -> [String: AgentBinding] { agentBindings }

    public mutating func restoreAgentBindings(_ stored: [String: AgentBinding], now: Date) {
        agentBindings = stored
        pruneAgentBindings(now: now)
    }

    public func agentSessionSummaries(now: Date) -> [AgentSessionSummary] {
        var titles: [String: String] = [:]
        for route in claudeCodeRoutes() {
            if let title = conversations[route.conversationKey]?.title { titles[route.conversationId] = title }
        }
        return agentSessions.sorted { $0.value.sequence > $1.value.sequence }.map { id, session in
            AgentSessionSummary(
                shortId: String(id.prefix(8)), folder: (session.cwd as NSString).lastPathComponent,
                activity: "\(session.activity)", ageSeconds: max(0, Int(now.timeIntervalSince(session.receivedAt))),
                boundTitle: agentBindings[id].flatMap { titles[$0.conversationId] }
            )
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
        var sessionsByWorkspace: [String: [(id: String, session: AgentSession)]] = [:]
        for (id, session) in agentSessions where session.entrypoint == AgentEvent.vscodeEntrypoint {
            guard let workspace = Self.longestMatch(of: session.cwd, in: workspaces) else { continue }
            sessionsByWorkspace[workspace, default: []].append((id, session))
        }
        var projection = StatusProjection(policy: FreshnessPolicy(maximumLifetime: Self.agentStatusLifetime))
        var reachability: [UUID: Reachability] = [:]
        for (workspace, tabs) in Dictionary(grouping: routes, by: \.workspacePath) {
            for (route, session) in pairings(tabs: tabs, sessions: sessionsByWorkspace[workspace] ?? []) {
                projection.record(observation(for: route.destinationId, from: session))
                reachability[route.destinationId] = route.reachability
            }
        }
        for destination in registry.allDestinations() {
            // A terminal session is its own route (its id is the session's), so no tab has to be guessed.
            guard case .appEntry = destination.locator,
                  let conversation = conversations[destination.conversationId], conversation.provider == AgentEvent.claudeCodeSource,
                  let sessionId = conversation.providerConversationId, let session = agentSessions[sessionId],
                  let connectorId = destination.connectorId, let connector = connectors[connectorId] else { continue }
            projection.record(observation(for: destination.id, from: session))
            reachability[destination.id] = connectionByInstallation[connector.installationId] != nil ? .connected : .disconnected
        }
        return Dictionary(uniqueKeysWithValues: reachability.map { id, reach in
            (id, projection.status(for: id, reachability: reach, now: now))
        })
    }

    /// A session bound to a tab is that tab's (the latest one, if a tab was reused). What is left over is paired only
    /// when exactly one tab and one session remain, so a leftover is never guessed at.
    private func pairings(
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

    private struct ClaudeCodeRoute {
        let destinationId: UUID
        /// The connector-derived id of the tab, stable across runs.
        let conversationId: String
        let conversationKey: UUID
        let workspacePath: String
        let reachability: Reachability
    }

    private func claudeCodeRoutes() -> [ClaudeCodeRoute] {
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
