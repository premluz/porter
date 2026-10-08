import Foundation

public enum BridgeBody: Sendable, Equatable {
    case hello(HelloPayload)
    case helloAck(HelloAckPayload)
    case inventorySnapshot(InventorySnapshotPayload)
    case destinationUpsert(DestinationUpsertPayload)
    case destinationRemove(DestinationRemovePayload)
    case heartbeat
    case snapshotRequest
    case activateRequest(ActivateRequestPayload)
    case activateResult(ActivationResult)
    case error(BridgeErrorPayload)

    public var type: MessageType {
        switch self {
        case .hello: .hello
        case .helloAck: .helloAck
        case .inventorySnapshot: .inventorySnapshot
        case .destinationUpsert: .destinationUpsert
        case .destinationRemove: .destinationRemove
        case .heartbeat: .heartbeat
        case .snapshotRequest: .snapshotRequest
        case .activateRequest: .activateRequest
        case .activateResult: .activateResult
        case .error: .error
        }
    }
}

public struct BridgeMessage: Sendable, Equatable {
    public let header: EnvelopeHeader
    public let body: BridgeBody
}

extension EnvelopeDecoder {
    private struct Carrier<Payload: Decodable>: Decodable {
        let payload: Payload
    }

    /// Header checks (size, version, type) run first, then the payload for exactly that type.
    public static func decodeMessage(_ data: Data) throws(EnvelopeRejection) -> BridgeMessage {
        let header = try decodeHeader(data)
        return BridgeMessage(header: header, body: try decodeBody(header.type, from: data))
    }

    private static func decodeBody(_ type: MessageType, from data: Data) throws(EnvelopeRejection) -> BridgeBody {
        switch type {
        case .hello:
            let hello = try payload(HelloPayload.self, data)
            try BridgeValidation.validate(hello)
            return .hello(hello)
        case .helloAck: return .helloAck(try payload(HelloAckPayload.self, data))
        case .inventorySnapshot:
            let snapshot = try payload(InventorySnapshotPayload.self, data)
            try BridgeValidation.validate(snapshot)
            return .inventorySnapshot(snapshot)
        case .destinationUpsert:
            let upsert = try payload(DestinationUpsertPayload.self, data)
            try BridgeValidation.validate(upsert.tab)
            return .destinationUpsert(upsert)
        case .destinationRemove: return .destinationRemove(try payload(DestinationRemovePayload.self, data))
        case .heartbeat: _ = try payload(EmptyPayload.self, data); return .heartbeat
        case .snapshotRequest: _ = try payload(EmptyPayload.self, data); return .snapshotRequest
        case .activateRequest: return .activateRequest(try payload(ActivateRequestPayload.self, data))
        case .activateResult: return .activateResult(try payload(ActivationResult.self, data))
        case .error: return .error(try payload(BridgeErrorPayload.self, data))
        // No payload contract until a status adapter is verified (TASK-013); refuse rather than guess.
        case .statusObserved: throw .unknownType(type.rawValue)
        }
    }

    private static func payload<Payload: Decodable>(
        _ type: Payload.Type, _ data: Data
    ) throws(EnvelopeRejection) -> Payload {
        do {
            return try ContractCoding.decoder().decode(Carrier<Payload>.self, from: data).payload
        } catch {
            throw .malformed("payload as \(Payload.self): \(error)")
        }
    }
}
