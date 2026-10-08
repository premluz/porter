import Foundation

extension BridgeCoordinator {
    mutating func applySnapshot(
        _ snapshot: InventorySnapshotPayload, binding: Binding, connection: ConnectionID, now: Date
    ) -> BridgeResult {
        let editorTabs = snapshot.editorTabs ?? []
        switch binding.kind {
        case .vscode:
            guard snapshot.tabs.isEmpty else {
                return violation(connection, .unauthorized, "an editor connector may not report browser tabs", close: true)
            }
            return applyEditorSnapshot(editorTabs, binding: binding, connection: connection, now: now)
        case .chrome:
            guard editorTabs.isEmpty else {
                return violation(connection, .unauthorized, "a browser connector may not report editor tabs", close: true)
            }
        }
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
        pruneRecency()
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

    /// Editor connectors report whole snapshots only; an incremental message from one is refused.
    mutating func applyIncremental(
        _ binding: Binding, _ connection: ConnectionID, _ apply: (inout BridgeCoordinator) -> BridgeResult
    ) -> BridgeResult {
        guard binding.kind == .chrome else {
            return violation(connection, .unauthorized, "an editor connector reports snapshots only", close: true)
        }
        return apply(&self)
    }

    /// A connector may only report providers it declared in hello, so a compromised page
    /// adapter cannot mint destinations for another provider.
    mutating func refusal(
        forProviders providers: [String], binding: Binding, connection: ConnectionID
    ) -> BridgeResult? {
        let declared = connectors[binding.connectorId]?.adapterVersions ?? [:]
        guard let undeclared = providers.first(where: { declared[$0] == nil }) else { return nil }
        return violation(connection, .unauthorized, "provider \(undeclared) not declared in hello", close: false)
    }

    private mutating func refusal(
        for tabs: [TabReport], binding: Binding, connection: ConnectionID
    ) -> BridgeResult? {
        refusal(forProviders: tabs.map(\.provider), binding: binding, connection: connection)
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
            // Same route: only its recency can have changed, which reorders the list but must not
            // invalidate a selection, so the revision stays put.
            let reordered = setRecency(previous.id, tab.lastActiveAt)
            return reordered ? BridgeResult(events: [.inventoryChanged(connectorId: binding.connectorId)]) : BridgeResult()
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
            setRecency(destination.id, tab.lastActiveAt)
            return BridgeResult(events: [.inventoryChanged(connectorId: binding.connectorId)])
        case .ignoredOlderRevision:
            return BridgeResult()
        case .rejected(let reason):
            return violation(connection, .malformed, "destination rejected: \(reason)", close: false)
        }
    }

    private mutating func conversationId(for tab: TabReport, binding: Binding, now: Date) -> UUID {
        conversationId(
            provider: tab.provider, providerConversationId: tab.providerConversationId, title: tab.title,
            binding: binding, now: now
        )
    }

    mutating func conversationId(
        provider: String, providerConversationId: String, title: String, binding: Binding, now: Date
    ) -> UUID {
        let key = IdentityKey(IdentityKey.Observed(
            provider: provider, account: nil, workspaceId: nil, providerConversationId: providerConversationId,
            connectorId: binding.connectorId, identityEpoch: Self.unverifiedIdentityEpoch, temporaryId: UUID()
        ))
        let id = conversationIdByKey[key] ?? UUID()
        conversationIdByKey[key] = id
        let existing = conversations[id]
        if existing?.title != title {
            conversations[id] = Conversation(
                id: id, provider: provider, providerConversationId: providerConversationId,
                accountScopeId: nil, workspaceScopeId: nil, title: title,
                createdAt: existing?.createdAt ?? now, lastObservedAt: now, revision: (existing?.revision ?? 0) + 1
            )
        }
        return id
    }

    @discardableResult
    mutating func setRecency(_ destinationId: UUID, _ date: Date?) -> Bool {
        guard let date, lastActive[destinationId] != date else { return false }
        lastActive[destinationId] = date
        return true
    }

    /// Routes that no longer exist take their recency with them, so the table stays as small as the list.
    mutating func pruneRecency() {
        lastActive = lastActive.filter { registry.destination($0.key) != nil }
    }

    static let browserCapabilities = [
        Capability(name: .discover, supported: true, reason: nil),
        Capability(name: .activate, supported: true, reason: nil),
        Capability(name: .observeStatus, supported: false, reason: "No verified status signal yet"),
    ]
}
