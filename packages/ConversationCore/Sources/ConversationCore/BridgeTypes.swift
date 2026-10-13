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
    /// An agent's working state changed; the panel should recompute statuses.
    case statusChanged
    /// A session was tied to, or released from, a tab; the app saves the ties so a restart keeps them.
    case agentBindingsChanged
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

