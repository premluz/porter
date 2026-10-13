import Foundation

/// All bridge decisions as a pure state machine: bytes in, bytes and events out. Sockets live
/// elsewhere, so identity, authorization and ordering rules are testable without a browser.
public struct BridgeCoordinator: Sendable {
    /// Account detection does not exist yet, so every connector shares one unverified epoch;
    /// conversations stay connector-scoped until a provider reports an account.
    static let unverifiedIdentityEpoch = "unverified"
    static let unboundConnectorId = "unbound"
    static let unboundEpoch = "none"
    static let protocolVersion = "1.0"
    /// Past this many, continuity is dropped (new IDs), never correctness.
    public static let maximumRememberedRoutes = 500

    let deviceId: UUID
    let activationTimeout: TimeInterval
    var registry: DestinationRegistry
    var sequencer = EventSequencer()
    var bindings: [ConnectionID: Binding] = [:]
    var connectionByInstallation: [UUID: ConnectionID] = [:]
    var connectors: [String: Connector] = [:]
    var conversations: [UUID: Conversation] = [:]
    var conversationIdByKey: [IdentityKey: UUID] = [:]
    var tabDestinations: [String: [Int: UUID]] = [:]
    var pending: [UUID: PendingActivation] = [:]
    var remembered: [RouteKey: RememberedRoute] = [:]
    /// Editor tabs have no tab ID, so a connector's routes are keyed by their provider conversation ID.
    var editorDestinations: [String: [String: UUID]] = [:]
    /// Desktop-app entries are keyed the same way, by the connector-derived conversation ID.
    var appDestinations: [String: [String: UUID]] = [:]
    /// Where an app lists each route, for ordering routes that have no time. Never compared across connectors.
    var listRank: [UUID: Int] = [:]
    /// When a connector last reported a turn in progress for a route. Only ever positive evidence; a report without
    /// it removes the route here, and the status that comes from it expires if the reports stop.
    var appWorking: [UUID: Date] = [:]
    var appTurnEnds: [UUID: TurnEnd] = [:]
    /// The few seconds around a click in Porter, per route. Bringing a chat forward makes its connector report it as
    /// just used, which would lift every chat to the top the moment it is opened; times inside this span are ignored.
    var ownActivations: [UUID: ClosedRange<Date>] = [:]
    static let ownActivationBefore: TimeInterval = 5
    static let ownActivationAfter: TimeInterval = 30
    /// When each route's tab was last the visible one, as its connector reports it. Ordering only.
    var lastActive: [UUID: Date] = [:]
    /// Agent sessions by ID, from hook events. Only the few fields of AgentEvent are ever kept.
    var agentSessions: [String: AgentSession] = [:]
    var agentSequence = 0
    /// Which tab each agent session belongs to, by session id.
    var agentBindings: [String: AgentBinding] = [:]

    public init(
        deviceId: UUID, locatorPolicy: LocatorPolicy = LocatorPolicy(), activationTimeout: TimeInterval = 5
    ) {
        self.deviceId = deviceId
        self.activationTimeout = activationTimeout
        self.registry = DestinationRegistry(locatorPolicy: locatorPolicy)
    }

    public static func connectorId(for installationId: UUID, kind: ConnectorKind = .chrome) -> String {
        "\(kind.idPrefix)-\(installationId.uuidString.lowercased())"
    }

    public mutating func handle(frame: Data, from connection: ConnectionID, now: Date) -> BridgeResult {
        let message: BridgeMessage
        do {
            message = try EnvelopeDecoder.decodeMessage(frame)
        } catch {
            return violation(connection, Self.code(for: error), "\(error)", close: true)
        }
        if case .hello(let hello) = message.body {
            return acceptHello(message.header, hello, from: connection, now: now)
        }
        guard let binding = bindings[connection] else {
            return violation(connection, .outOfOrder, "\(message.header.type.rawValue) before hello", close: true)
        }
        guard message.header.connectorId == binding.connectorId,
              message.header.connectionEpoch == binding.epoch else {
            return violation(connection, .unauthorized, "envelope does not match this connection", close: true)
        }
        guard Self.connectorMaySend(message.body.type) else {
            return violation(connection, .unauthorized, "\(message.body.type.rawValue) is registry-only", close: true)
        }
        return admit(message, binding: binding, from: connection, now: now)
    }

    public mutating func disconnect(_ connection: ConnectionID, now: Date) -> BridgeResult {
        guard let binding = bindings.removeValue(forKey: connection) else { return BridgeResult() }
        connectionByInstallation[binding.installationId] = nil
        var result = BridgeResult(events: [.connectorDisconnected(connectorId: binding.connectorId)])
        for (requestId, request) in pending where request.connection == connection {
            pending[requestId] = nil
            result.events.append(.activation(Self.result(requestId, request, .timeout)))
        }
        return result
    }

    private mutating func admit(
        _ message: BridgeMessage, binding: Binding, from connection: ConnectionID, now: Date
    ) -> BridgeResult {
        let header = message.header
        switch sequencer.admit(connectorId: header.connectorId, epoch: header.connectionEpoch, sequence: header.sequence) {
        case .duplicate:
            return BridgeResult()
        case .staleEpoch, .unknownConnector:
            return violation(connection, .outOfOrder, "sequence stream not open", close: true)
        case .accepted:
            return dispatch(message.body, binding: binding, from: connection, now: now)
        case .gap(let expected, let received):
            let applied = dispatch(message.body, binding: binding, from: connection, now: now)
            let detail = "expected sequence \(expected), received \(received)"
            return applied + violation(connection, .outOfOrder, detail, close: false) + requestSnapshot(connection)
        }
    }

    private mutating func dispatch(
        _ body: BridgeBody, binding: Binding, from connection: ConnectionID, now: Date
    ) -> BridgeResult {
        switch body {
        case .inventorySnapshot(let snapshot):
            applySnapshot(snapshot, binding: binding, connection: connection, now: now)
        case .destinationUpsert(let upsert):
            applyIncremental(binding, connection) { $0.applyUpsert(upsert.tab, binding: binding, connection: connection, now: now) }
        case .destinationRemove(let remove):
            applyIncremental(binding, connection) { $0.applyRemove(remove.tabId, binding: binding) }
        case .heartbeat: recordHeartbeat(binding, now: now)
        case .activateResult(let result): completeActivation(result, from: connection)
        case .error(let error):
            violationEvent(connection, error.code, "connector reported: \(error.message)")
        case .hello, .helloAck, .snapshotRequest, .activateRequest:
            violation(connection, .unauthorized, "unexpected message", close: true)
        }
    }

    /// Hello is the only message that opens a stream, so it cannot be a registry-only type either.
    private static func connectorMaySend(_ type: MessageType) -> Bool {
        switch type {
        case .hello, .inventorySnapshot, .destinationUpsert, .destinationRemove, .heartbeat, .activateResult, .error:
            true
        case .helloAck, .snapshotRequest, .activateRequest, .statusObserved:
            false
        }
    }

    private static func code(for rejection: EnvelopeRejection) -> BridgeErrorCode {
        switch rejection {
        case .unsupportedMajorVersion: .unsupportedVersion
        case .oversized, .malformed, .unknownType: .malformed
        }
    }

    static func result(_ requestId: UUID, _ request: PendingActivation, _ outcome: ActivationOutcome) -> ActivationResult {
        ActivationResult(
            requestId: requestId, destinationId: request.destinationId,
            destinationRevision: request.destinationRevision, outcome: outcome
        )
    }
}
