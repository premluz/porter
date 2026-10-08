import Foundation

private struct OutboundEnvelope<Payload: Encodable>: Encodable {
    let protocolVersion: String
    let messageId: UUID
    let connectorId: String
    let connectionEpoch: String
    let sequence: Int
    let type: String
    let sentAt: Date
    let payload: Payload
}

extension BridgeCoordinator {
    mutating func send<Payload: Encodable>(
        _ type: MessageType, _ payload: Payload, to connection: ConnectionID
    ) -> BridgeResult {
        let binding = bindings[connection]
        let sequence = binding?.outboundSequence ?? 0
        bindings[connection]?.outboundSequence = sequence + 1
        let envelope = OutboundEnvelope(
            protocolVersion: Self.protocolVersion, messageId: UUID(),
            connectorId: binding?.connectorId ?? Self.unboundConnectorId,
            connectionEpoch: binding?.epoch ?? Self.unboundEpoch,
            sequence: sequence, type: type.rawValue, sentAt: Date(), payload: payload
        )
        // Encoding fixed, Sendable value types cannot fail; a failure would be a programming error.
        guard let data = try? ContractCoding.encoder().encode(envelope) else {
            preconditionFailure("Bridge envelope for \(type.rawValue) failed to encode")
        }
        return BridgeResult(outbound: [Outbound(connection: connection, action: .send(data))])
    }

    mutating func requestSnapshot(_ connection: ConnectionID) -> BridgeResult {
        send(.snapshotRequest, EmptyPayload(), to: connection)
    }

    /// Tells the peer why, records why, and optionally ends the connection.
    mutating func violation(
        _ connection: ConnectionID, _ code: BridgeErrorCode, _ detail: String, close: Bool
    ) -> BridgeResult {
        var result = send(.error, BridgeErrorPayload(code: code, message: String(detail.prefix(200))), to: connection)
        result.events.append(.protocolViolation(connection: connection, code: code, detail: detail))
        if close { result.outbound.append(Outbound(connection: connection, action: .close)) }
        return result
    }

    func violationEvent(_ connection: ConnectionID, _ code: BridgeErrorCode, _ detail: String) -> BridgeResult {
        BridgeResult(events: [.protocolViolation(connection: connection, code: code, detail: detail)])
    }
}
