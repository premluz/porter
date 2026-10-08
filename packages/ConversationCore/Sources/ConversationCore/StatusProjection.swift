import Foundation

/// How long an observation may be relied on. Lifetime is the adapter's declared window
/// (expiresAt − observedAt, both on the page's clock, so skew cancels out), capped and
/// applied from receivedAt on Porter's clock. A page clock never extends freshness.
public struct FreshnessPolicy: Sendable {
    /// Inactive observed tabs; actively watched DOM signals declare a shorter window themselves.
    public static let defaultMaximumLifetime: TimeInterval = 60

    public let maximumLifetime: TimeInterval

    public init(maximumLifetime: TimeInterval = defaultMaximumLifetime) {
        self.maximumLifetime = maximumLifetime
    }

    public func expiry(of observation: StatusObservation) -> Date {
        let declared = max(0, observation.expiresAt.timeIntervalSince(observation.observedAt))
        return observation.receivedAt.addingTimeInterval(min(declared, maximumLifetime))
    }
}

public struct DestinationStatus: Equatable, Sendable {
    public let display: DisplayStatus
    public let freshness: Freshness
    public let reachability: Reachability
    /// Kept so detail views can show what was last seen and its age; never shown as current.
    public let lastKnown: StatusObservation?

    public init(display: DisplayStatus, freshness: Freshness, reachability: Reachability, lastKnown: StatusObservation?) {
        self.display = display
        self.freshness = freshness
        self.reachability = reachability
        self.lastKnown = lastKnown
    }
}

/// Latest evidence per destination, reduced to a display status that never outlives its evidence.
public struct StatusProjection: Sendable {
    public let policy: FreshnessPolicy
    private var latest: [UUID: StatusObservation] = [:]
    private var uncertain: Set<UUID> = []

    public init(policy: FreshnessPolicy = FreshnessPolicy()) {
        self.policy = policy
    }

    /// Returns false when an older observation from the same connection arrives late.
    @discardableResult
    public mutating func record(_ observation: StatusObservation) -> Bool {
        if let current = latest[observation.destinationId],
           current.connectionEpoch == observation.connectionEpoch,
           current.sequence >= observation.sequence {
            return false
        }
        latest[observation.destinationId] = observation
        return true
    }

    /// After a sequence gap: suppress claims until a snapshot reconciles these destinations.
    public mutating func markUncertain(_ destinationIds: some Sequence<UUID>) {
        uncertain.formUnion(destinationIds)
    }

    /// A snapshot is authoritative for the destinations it covers, including absent ones.
    public mutating func applySnapshot(_ observations: [StatusObservation], covering destinationIds: Set<UUID>) {
        for id in destinationIds { latest[id] = nil }
        for observation in observations where destinationIds.contains(observation.destinationId) {
            latest[observation.destinationId] = observation
        }
        uncertain.subtract(destinationIds)
    }

    public mutating func forget(_ destinationId: UUID) {
        latest[destinationId] = nil
        uncertain.remove(destinationId)
    }

    public func status(for destinationId: UUID, reachability: Reachability, now: Date) -> DestinationStatus {
        guard let observation = latest[destinationId] else {
            return DestinationStatus(display: .unknown, freshness: .unknown, reachability: reachability, lastKnown: nil)
        }
        let freshness = freshness(of: observation, reachability: reachability, now: now)
        let display = freshness == .fresh ? Self.displayStatus(of: observation) : .unknown
        return DestinationStatus(display: display, freshness: freshness, reachability: reachability, lastKnown: observation)
    }

    /// One conversation can have several routes; only fresh ones vote, highest precedence wins.
    public static func conversationDisplay(_ statuses: [DestinationStatus]) -> DisplayStatus {
        statuses.filter { $0.freshness == .fresh }.map(\.display).min() ?? .unknown
    }

    private func freshness(of observation: StatusObservation, reachability: Reachability, now: Date) -> Freshness {
        if uncertain.contains(observation.destinationId) || observation.evidenceKind == .none { return .unknown }
        if reachability != .connected { return .stale }
        return now < policy.expiry(of: observation) ? .fresh : .stale
    }

    /// What an observation says, ignoring whether it is still fresh.
    public static func displayStatus(of observation: StatusObservation) -> DisplayStatus {
        if observation.attention == .needsUser { return .needsUser }
        if observation.activity == .working { return .working }
        if observation.attention == .newResponse { return .newResponse }
        if observation.activity == .idle { return .idle }
        return .unknown
    }
}
