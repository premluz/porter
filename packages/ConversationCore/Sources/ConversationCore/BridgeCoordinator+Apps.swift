import Foundation

extension BridgeCoordinator {
    /// Whole-snapshot replacement for a desktop-app connector, like an editor's: an entry that is not in
    /// the list is gone, and there is no continuity memory because the app gives no ID to key it on.
    mutating func applyAppSnapshot(
        _ entries: [AppEntryReport], binding: Binding, connection: ConnectionID, now: Date
    ) -> BridgeResult {
        if let refusal = refusal(forProviders: entries.map(\.provider), binding: binding, connection: connection) {
            return refusal
        }
        let removed = removeMissingAppEntries(Set(entries.map(\.providerConversationId)), connectorId: binding.connectorId)
        var changed = removed.inventory
        var statusChanged = removed.status
        var result = BridgeResult()
        for entry in entries {
            switch storeAppEntry(entry, binding: binding, now: now) {
            case .unchanged: break
            case .changed: changed = true
            case .rejected(let reason): result = result + violation(connection, .malformed, reason, close: false)
            }
            if let id = appDestinations[binding.connectorId]?[entry.providerConversationId], setWorking(id, entry.working, now: now) {
                statusChanged = true
            }
            if let id = appDestinations[binding.connectorId]?[entry.providerConversationId], setTurnEnd(id, entry: entry) {
                statusChanged = true
            }
        }
        pruneRecency()
        if changed { result.events.append(.inventoryChanged(connectorId: binding.connectorId)) }
        if statusChanged { result.events.append(.statusChanged) }
        return result
    }

    private mutating func removeMissingAppEntries(_ reported: Set<String>, connectorId: String) -> (inventory: Bool, status: Bool) {
        var inventory = false
        var status = false
        for (key, id) in appDestinations[connectorId] ?? [:] where !reported.contains(key) {
            registry.remove(id)
            appDestinations[connectorId]?[key] = nil
            if appWorking.removeValue(forKey: id) != nil { status = true }
            if appTurnEnds.removeValue(forKey: id) != nil { status = true }
            inventory = true
        }
        return (inventory, status)
    }

    private enum StoreOutcome {
        case unchanged, changed
        case rejected(String)
    }

    private mutating func storeAppEntry(_ entry: AppEntryReport, binding: Binding, now: Date) -> StoreOutcome {
        let conversationId = conversationId(
            provider: entry.provider, providerConversationId: entry.providerConversationId, title: entry.title,
            binding: binding, now: now
        )
        let existingId = appDestinations[binding.connectorId]?[entry.providerConversationId]
        let previous = existingId.flatMap { registry.destination($0) }
        let locator = Locator.appEntry(AppEntryLocator(
            bundleId: entry.bundleId, title: entry.title, ordinal: entry.ordinal, workspacePath: entry.workspacePath
        ))
        if let previous, previous.locator == locator, previous.conversationId == conversationId {
            let ranked = setRank(previous.id, entry.position)
            return setRecency(previous.id, entry.lastActiveAt) || ranked ? .changed : .unchanged
        }
        let destination = Destination(
            id: existingId ?? UUID(), conversationId: conversationId, deviceId: deviceId, connectorId: binding.connectorId,
            identityEpoch: Self.unverifiedIdentityEpoch, locator: locator, capabilities: Self.appCapabilities,
            lastVerifiedAt: now, revision: (previous?.revision ?? 0) + 1
        )
        switch registry.upsert(destination) {
        case .inserted, .updated:
            appDestinations[binding.connectorId, default: [:]][entry.providerConversationId] = destination.id
            setRecency(destination.id, entry.lastActiveAt)
            setRank(destination.id, entry.position)
            return .changed
        case .ignoredOlderRevision:
            return .unchanged
        case .rejected(let reason):
            return .rejected("destination rejected: \(reason)")
        }
    }

    @discardableResult
    mutating func setRank(_ destinationId: UUID, _ position: Int?) -> Bool {
        guard listRank[destinationId] != position else { return false }
        listRank[destinationId] = position
        return true
    }

    static let appCapabilities = [
        Capability(name: .discover, supported: true, reason: nil),
        Capability(name: .activate, supported: true, reason: nil),
        Capability(name: .observeStatus, supported: false, reason: "The app's unread marker is not a verified status signal"),
    ]
}
