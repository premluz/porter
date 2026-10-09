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
        var changed = false
        let reported = Set(entries.map(\.providerConversationId))
        for (key, destinationId) in appDestinations[binding.connectorId] ?? [:] where !reported.contains(key) {
            registry.remove(destinationId)
            appDestinations[binding.connectorId]?[key] = nil
            changed = true
        }
        var result = BridgeResult()
        for entry in entries {
            switch storeAppEntry(entry, binding: binding, now: now) {
            case .unchanged: break
            case .changed: changed = true
            case .rejected(let reason): result = result + violation(connection, .malformed, reason, close: false)
            }
        }
        pruneRecency()
        if changed { result.events.append(.inventoryChanged(connectorId: binding.connectorId)) }
        return result
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
        let locator = Locator.appEntry(AppEntryLocator(bundleId: entry.bundleId, title: entry.title, ordinal: entry.ordinal))
        if let previous, previous.locator == locator, previous.conversationId == conversationId {
            return setRecency(previous.id, entry.lastActiveAt) ? .changed : .unchanged
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
            return .changed
        case .ignoredOlderRevision:
            return .unchanged
        case .rejected(let reason):
            return .rejected("destination rejected: \(reason)")
        }
    }

    static let appCapabilities = [
        Capability(name: .discover, supported: true, reason: nil),
        Capability(name: .activate, supported: true, reason: nil),
        Capability(name: .observeStatus, supported: false, reason: "The app's unread marker is not a verified status signal"),
    ]
}
