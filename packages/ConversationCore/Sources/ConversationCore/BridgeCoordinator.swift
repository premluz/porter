import Foundation

/// Opaque handle the I/O layer assigns to one connector connection.
public struct ConnectionID: Hashable, Sendable, CustomStringConvertible {
    public let value: UInt64

    public init(_ value: UInt64) { self.value = value }

    public var description: String { "connection-\(value)" }
}

public enum OutboundAction: Sendable, Equatable {
    case send(Data)
    case close
}

public struct Outbound: Sendable, Equatable {
    public let connection: ConnectionID
    public let action: OutboundAction
}

public enum BridgeEvent: Sendable, Equatable {
    case connectorConnected(connectorId: String)
    case connectorDisconnected(connectorId: String)
    case inventoryChanged(connectorId: String)
    case activation(ActivationResult)
    case protocolViolation(connection: ConnectionID, code: BridgeErrorCode, detail: String)
}

public struct BridgeResult: Sendable, Equatable {
    public var outbound: [Outbound] = []
    public var events: [BridgeEvent] = []

    public init(outbound: [Outbound] = [], events: [BridgeEvent] = []) {
        self.outbound = outbound
        self.events = events
    }

    static func + (lhs: BridgeResult, rhs: BridgeResult) -> BridgeResult {
        BridgeResult(outbound: lhs.outbound + rhs.outbound, events: lhs.events + rhs.events)
    }
}

struct Binding: Sendable {
    let connectorId: String
    let kind: ConnectorKind
    let installationId: UUID
    let epoch: String
    var outboundSequence = 0
}

/// A tab and the chat it showed. Tab IDs are unique within a browser session, so a returning tab
/// showing the same chat is the same route; a different chat in the same tab never is.
struct RouteKey: Hashable, Sendable {
    let connectorId: String
    let tabId: Int
    let providerConversationId: String
}

struct RememberedRoute: Sendable {
    let destinationId: UUID
    let revision: Int
}

struct PendingActivation: Sendable {
    let connection: ConnectionID
    let destinationId: UUID
    let destinationRevision: Int
    let deadline: Date
}

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
