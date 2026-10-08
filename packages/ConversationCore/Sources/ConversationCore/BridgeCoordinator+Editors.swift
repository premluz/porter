import Foundation

extension BridgeCoordinator {
    /// Whole-snapshot replacement for an editor connector. A tab that is not in the list is gone;
    /// there is no continuity memory here, because editor tabs rarely drop out and have no tab ID to key it on.
    mutating func applyEditorSnapshot(
        _ tabs: [EditorTabReport], binding: Binding, connection: ConnectionID, now: Date
    ) -> BridgeResult {
        if let refusal = refusal(forProviders: tabs.map(\.provider), binding: binding, connection: connection) {
            return refusal
        }
        var changed = false
        let reported = Set(tabs.map(\.providerConversationId))
        for (conversationKey, destinationId) in editorDestinations[binding.connectorId] ?? [:] where !reported.contains(conversationKey) {
            registry.remove(destinationId)
            editorDestinations[binding.connectorId]?[conversationKey] = nil
            changed = true
        }
        var result = BridgeResult()
        for tab in tabs {
            switch storeEditorTab(tab, binding: binding, now: now) {
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

    private mutating func storeEditorTab(_ tab: EditorTabReport, binding: Binding, now: Date) -> StoreOutcome {
        let conversationId = conversationId(
            provider: tab.provider, providerConversationId: tab.providerConversationId, title: tab.title,
            binding: binding, now: now
        )
        let existingId = editorDestinations[binding.connectorId]?[tab.providerConversationId]
        let previous = existingId.flatMap { registry.destination($0) }
        let locator = Locator.editorTab(EditorTabLocator(
            bundleId: LocatorPolicy.vscodeBundleId, workspacePath: tab.workspacePath,
            viewColumn: tab.viewColumn, index: tab.index
        ))
        if let previous, previous.locator == locator, previous.conversationId == conversationId {
            return setRecency(previous.id, tab.lastActiveAt) ? .changed : .unchanged
        }
        let destination = Destination(
            id: existingId ?? UUID(), conversationId: conversationId, deviceId: deviceId, connectorId: binding.connectorId,
            identityEpoch: Self.unverifiedIdentityEpoch, locator: locator, capabilities: Self.browserCapabilities,
            lastVerifiedAt: now, revision: (previous?.revision ?? 0) + 1
        )
        switch registry.upsert(destination) {
        case .inserted, .updated:
            editorDestinations[binding.connectorId, default: [:]][tab.providerConversationId] = destination.id
            setRecency(destination.id, tab.lastActiveAt)
            return .changed
        case .ignoredOlderRevision:
            return .unchanged
        case .rejected(let reason):
            return .rejected("destination rejected: \(reason)")
        }
    }
}

/// What the host must do before an activation request can work: bring the right editor window
/// forward, since the request only acts inside whichever window is in front.
public struct ActivationPreparation: Sendable, Equatable {
    public let bundleId: String
    public let workspacePath: String

    public init(bundleId: String, workspacePath: String) {
        self.bundleId = bundleId
        self.workspacePath = workspacePath
    }
}
