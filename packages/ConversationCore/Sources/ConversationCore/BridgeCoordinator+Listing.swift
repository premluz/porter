import Foundation

/// One selectable route, with enough context to tell identical titles apart.
public struct DestinationRow: Codable, Sendable, Equatable {
    public let destinationId: UUID
    public let revision: Int
    public let conversationId: UUID
    /// The provider's own chat ID, stable across restarts; `conversationId` is not.
    public let providerConversationId: String
    public let provider: String
    public let title: String
    public let profileAlias: String?
    public let connectorId: String
    public let reachability: Reachability
    public let tabId: Int?
    public let windowId: Int?
    public let url: String?
    /// More than one route to the same conversation: the user chooses, Porter never picks.
    public let routeCount: Int
    /// When this route's tab was last the visible one, if its connector said. Orders the list.
    public let lastActiveAt: Date?

    public init(
        destinationId: UUID, revision: Int, conversationId: UUID, providerConversationId: String, provider: String,
        title: String, profileAlias: String?, connectorId: String, reachability: Reachability,
        tabId: Int?, windowId: Int?, url: String?, routeCount: Int, lastActiveAt: Date? = nil
    ) {
        self.destinationId = destinationId
        self.revision = revision
        self.conversationId = conversationId
        self.providerConversationId = providerConversationId
        self.provider = provider
        self.title = title
        self.profileAlias = profileAlias
        self.connectorId = connectorId
        self.reachability = reachability
        self.tabId = tabId
        self.windowId = windowId
        self.url = url
        self.routeCount = routeCount
        self.lastActiveAt = lastActiveAt
    }
}

extension BridgeCoordinator {
    public func rows() -> [DestinationRow] {
        let routeCounts = Dictionary(grouping: registry.allDestinations(), by: \.conversationId).mapValues(\.count)
        return registry.allDestinations().compactMap { row(for: $0, routeCount: routeCounts) }
            .sorted {
                ($0.profileAlias ?? "", $0.title, $0.tabId ?? 0, $0.providerConversationId)
                    < ($1.profileAlias ?? "", $1.title, $1.tabId ?? 0, $1.providerConversationId)
            }
    }

    private func row(for destination: Destination, routeCount: [UUID: Int]) -> DestinationRow? {
        guard let conversation = conversations[destination.conversationId],
              let providerConversationId = conversation.providerConversationId,
              let connectorId = destination.connectorId else { return nil }
        var tabId: Int?
        var windowId: Int?
        var url: String?
        if case .browserTab(let tab) = destination.locator {
            (tabId, windowId, url) = (tab.tabId, tab.windowIdHint, tab.canonicalUrl)
        }
        let connector = connectors[connectorId]
        let live = connector.map { connectionByInstallation[$0.installationId] != nil } ?? false
        return DestinationRow(
            destinationId: destination.id, revision: destination.revision, conversationId: conversation.id,
            providerConversationId: providerConversationId, provider: conversation.provider, title: conversation.title, profileAlias: connector?.profileAlias,
            connectorId: connectorId, reachability: live ? .connected : .disconnected,
            tabId: tabId, windowId: windowId, url: url, routeCount: routeCount[conversation.id] ?? 1,
            lastActiveAt: lastActive[destination.id]
        )
    }
}

public struct ConnectorSummary: Codable, Sendable, Equatable {
    public let connectorId: String
    public let profileAlias: String?
    public let reachability: Reachability
    public let routeCount: Int

    public init(connectorId: String, profileAlias: String?, reachability: Reachability, routeCount: Int) {
        self.connectorId = connectorId
        self.profileAlias = profileAlias
        self.reachability = reachability
        self.routeCount = routeCount
    }
}

extension BridgeCoordinator {
    /// A connector with no supported tabs still appears, so "connected but empty" is visible.
    public func connectorSummaries() -> [ConnectorSummary] {
        connectors.values.map { connector in
            ConnectorSummary(
                connectorId: connector.id, profileAlias: connector.profileAlias,
                reachability: connectionByInstallation[connector.installationId] == nil ? .disconnected : .connected,
                routeCount: (tabDestinations[connector.id]?.count ?? 0) + (editorDestinations[connector.id]?.count ?? 0)
            )
        }.sorted { ($0.profileAlias ?? "", $0.connectorId) < ($1.profileAlias ?? "", $1.connectorId) }
    }
}

extension BridgeCoordinator {
    /// Exposed so tests can prove the memory of retired routes stays bounded.
    public var rememberedRouteCount: Int { remembered.count }
}
