import Foundation

extension BridgeCoordinator {
    mutating func applySnapshot(
        _ snapshot: InventorySnapshotPayload, binding: Binding, connection: ConnectionID, now: Date
    ) -> BridgeResult {
        if let refusal = refusal(for: snapshot.tabs, binding: binding, connection: connection) { return refusal }
        var result = BridgeResult()
        let reported = Set(snapshot.tabs.map(\.tabId))
        for tabId in (tabDestinations[binding.connectorId] ?? [:]).keys where !reported.contains(tabId) {
            retire(tabId: tabId, connectorId: binding.connectorId)
            result.events.append(.inventoryChanged(connectorId: binding.connectorId))
        }
        for tab in snapshot.tabs {
            result = result + store(tab, binding: binding, connection: connection, now: now)
        }
        return result
    }

    mutating func applyUpsert(
        _ tab: TabReport, binding: Binding, connection: ConnectionID, now: Date
    ) -> BridgeResult {
        if let refusal = refusal(for: [tab], binding: binding, connection: connection) { return refusal }
        return store(tab, binding: binding, connection: connection, now: now)
    }

    mutating func applyRemove(_ tabId: Int, binding: Binding) -> BridgeResult {
        guard tabDestinations[binding.connectorId]?[tabId] != nil else { return BridgeResult() }
        retire(tabId: tabId, connectorId: binding.connectorId)
        return BridgeResult(events: [.inventoryChanged(connectorId: binding.connectorId)])
    }

    /// Removes a route from the registry but remembers its ID and revision for this connection.
    private mutating func retire(tabId: Int, connectorId: String) {
        guard let destinationId = tabDestinations[connectorId]?[tabId] else { return }
        if let destination = registry.destination(destinationId),
           let chat = conversations[destination.conversationId]?.providerConversationId {
            if remembered.count >= Self.maximumRememberedRoutes { remembered.removeAll() }
            remembered[RouteKey(connectorId: connectorId, tabId: tabId, providerConversationId: chat)] =
                RememberedRoute(destinationId: destinationId, revision: destination.revision)
        }
        registry.remove(destinationId)
        tabDestinations[connectorId]?[tabId] = nil
    }

    /// A connector may only report providers it declared in hello, so a compromised page
    /// adapter cannot mint destinations for another provider.
    private mutating func refusal(
        for tabs: [TabReport], binding: Binding, connection: ConnectionID
    ) -> BridgeResult? {
        let declared = connectors[binding.connectorId]?.adapterVersions ?? [:]
        guard let undeclared = tabs.first(where: { declared[$0.provider] == nil }) else { return nil }
        return violation(connection, .unauthorized, "provider \(undeclared.provider) not declared in hello", close: false)
    }

    private mutating func store(
        _ tab: TabReport, binding: Binding, connection: ConnectionID, now: Date
    ) -> BridgeResult {
        let conversationId = conversationId(for: tab, binding: binding, now: now)
        let key = RouteKey(connectorId: binding.connectorId, tabId: tab.tabId, providerConversationId: tab.providerConversationId)
        let existingId = tabDestinations[binding.connectorId]?[tab.tabId]
        let previous = existingId.flatMap { registry.destination($0) }
        let returning = existingId == nil ? remembered[key] : nil
        let locator = Locator.browserTab(BrowserTabLocator(
            connectorId: binding.connectorId, connectionEpoch: binding.epoch, tabId: tab.tabId,
            windowIdHint: tab.windowId, canonicalUrl: tab.canonicalUrl
        ))
        // Revision moves only when the route changes, so a periodic identical snapshot does not
        // invalidate a selection the user is about to open.
        if let previous, previous.locator == locator, previous.conversationId == conversationId {
            return BridgeResult()
        }
        let destination = Destination(
            id: existingId ?? returning?.destinationId ?? UUID(), conversationId: conversationId, deviceId: deviceId,
            connectorId: binding.connectorId, identityEpoch: Self.unverifiedIdentityEpoch, locator: locator,
            capabilities: Self.browserCapabilities, lastVerifiedAt: now,
            revision: (previous?.revision ?? returning?.revision ?? 0) + 1
        )
        switch registry.upsert(destination) {
        case .inserted, .updated:
            tabDestinations[binding.connectorId, default: [:]][tab.tabId] = destination.id
            remembered[key] = nil
            return BridgeResult(events: [.inventoryChanged(connectorId: binding.connectorId)])
        case .ignoredOlderRevision:
            return BridgeResult()
        case .rejected(let reason):
            return violation(connection, .malformed, "destination rejected: \(reason)", close: false)
        }
    }

    private mutating func conversationId(for tab: TabReport, binding: Binding, now: Date) -> UUID {
        let key = IdentityKey(IdentityKey.Observed(
            provider: tab.provider, account: nil, workspaceId: nil, providerConversationId: tab.providerConversationId,
            connectorId: binding.connectorId, identityEpoch: Self.unverifiedIdentityEpoch, temporaryId: UUID()
        ))
        let id = conversationIdByKey[key] ?? UUID()
        conversationIdByKey[key] = id
        let existing = conversations[id]
        if existing?.title != tab.title {
            conversations[id] = Conversation(
                id: id, provider: tab.provider, providerConversationId: tab.providerConversationId,
                accountScopeId: nil, workspaceScopeId: nil, title: tab.title,
                createdAt: existing?.createdAt ?? now, lastObservedAt: now, revision: (existing?.revision ?? 0) + 1
            )
        }
        return id
    }

    static let browserCapabilities = [
        Capability(name: .discover, supported: true, reason: nil),
        Capability(name: .activate, supported: true, reason: nil),
        Capability(name: .observeStatus, supported: false, reason: "No verified status signal yet"),
    ]
}
