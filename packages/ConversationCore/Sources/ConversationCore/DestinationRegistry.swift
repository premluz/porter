import Foundation

public enum UpsertRejection: Error, Equatable, Sendable {
    case locator(LocatorRejection)
    /// The destination's connector disagrees with its browser-tab locator.
    case inconsistentConnector
    /// Sent under an identity epoch the connector has since replaced (e.g. account switch).
    case staleIdentityEpoch
}

public enum UpsertOutcome: Equatable, Sendable {
    case inserted, updated, ignoredOlderRevision
    case rejected(UpsertRejection)
}

/// Re-checked immediately before every open, so a selection made earlier cannot reach a changed target.
public enum DestinationResolution: Equatable, Sendable {
    case current(Destination)
    case gone
    case changed(currentRevision: Int)
    case accountChanged

    public var failureOutcome: ActivationOutcome? {
        switch self {
        case .current: nil
        case .gone: .targetGone
        case .changed: .targetChanged
        case .accountChanged: .accountChanged
        }
    }
}

public struct DestinationRegistry: Sendable {
    public let locatorPolicy: LocatorPolicy
    private var byId: [UUID: Destination] = [:]
    private var identityEpochs: [String: String] = [:]
    private var retiredByAccountChange: Set<UUID> = []

    public init(locatorPolicy: LocatorPolicy = LocatorPolicy()) {
        self.locatorPolicy = locatorPolicy
    }

    public mutating func upsert(_ destination: Destination) -> UpsertOutcome {
        if let rejection = rejection(for: destination) { return .rejected(rejection) }
        guard let existing = byId[destination.id] else {
            byId[destination.id] = destination
            return .inserted
        }
        guard destination.revision > existing.revision else { return .ignoredOlderRevision }
        byId[destination.id] = destination
        return .updated
    }

    public mutating func remove(_ destinationId: UUID) {
        byId[destinationId] = nil
    }

    /// Starts a new identity epoch for a connector and retires every destination from older epochs.
    @discardableResult
    public mutating func beginIdentityEpoch(_ epoch: String, connectorId: String) -> [UUID] {
        identityEpochs[connectorId] = epoch
        let retired = byId.values
            .filter { $0.connectorId == connectorId && $0.identityEpoch != epoch }
            .map(\.id)
        for id in retired { byId[id] = nil }
        retiredByAccountChange.formUnion(retired)
        return retired
    }

    public func resolve(_ destinationId: UUID, expectedRevision: Int) -> DestinationResolution {
        if retiredByAccountChange.contains(destinationId) { return .accountChanged }
        guard let destination = byId[destinationId] else { return .gone }
        guard destination.revision == expectedRevision else { return .changed(currentRevision: destination.revision) }
        return .current(destination)
    }

    public func destination(_ destinationId: UUID) -> Destination? {
        byId[destinationId]
    }

    public func allDestinations() -> [Destination] {
        Array(byId.values)
    }

    /// More than one result means the user chooses; Porter never picks a "closest" route.
    public func destinations(forConversation conversationId: UUID) -> [Destination] {
        byId.values.filter { $0.conversationId == conversationId }.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func rejection(for destination: Destination) -> UpsertRejection? {
        do {
            try locatorPolicy.validate(destination.locator)
        } catch {
            return .locator(error)
        }
        if case .browserTab(let tab) = destination.locator, tab.connectorId != destination.connectorId {
            return .inconsistentConnector
        }
        if let connectorId = destination.connectorId, let current = identityEpochs[connectorId],
           current != destination.identityEpoch {
            return .staleIdentityEpoch
        }
        return nil
    }
}
