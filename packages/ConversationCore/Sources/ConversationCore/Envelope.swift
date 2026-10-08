import Foundation

public enum MessageType: String, Codable, Sendable, CaseIterable {
    case hello
    case helloAck = "hello.ack"
    case inventorySnapshot = "inventory.snapshot"
    case destinationUpsert = "destination.upsert"
    case destinationRemove = "destination.remove"
    case statusObserved = "status.observed"
    case heartbeat
    case snapshotRequest = "snapshot.request"
    case activateRequest = "activate.request"
    case activateResult = "activate.result"
    case error
}

/// Routing fields of envelope.schema.json. Payloads are decoded per message type by their consumer.
public struct EnvelopeHeader: Sendable, Equatable {
    public let protocolVersion: String
    public let messageId: UUID
    public let connectorId: String
    public let connectionEpoch: String
    public let sequence: Int
    public let type: MessageType
    public let sentAt: Date
}

public enum EnvelopeRejection: Error, Equatable, Sendable {
    case oversized(bytes: Int)
    case malformed(String)
    case unsupportedMajorVersion(String)
    case unknownType(String)
}

public enum EnvelopeDecoder {
    public static let maximumBytes = 64 * 1024
    public static let supportedMajorVersion = 1

    private struct Wire: Decodable {
        let protocolVersion: String
        let messageId: UUID
        let connectorId: String
        let connectionEpoch: String
        let sequence: Int
        let type: String
        let sentAt: Date
    }

    /// Size is checked before any parsing so an oversized frame is never decoded.
    public static func decodeHeader(_ data: Data) throws(EnvelopeRejection) -> EnvelopeHeader {
        guard data.count <= maximumBytes else { throw .oversized(bytes: data.count) }
        let wire: Wire
        do {
            wire = try ContractCoding.decoder().decode(Wire.self, from: data)
        } catch {
            throw .malformed(String(describing: error))
        }
        let major = wire.protocolVersion.split(separator: ".").first.flatMap { Int($0) }
        guard major == supportedMajorVersion else { throw .unsupportedMajorVersion(wire.protocolVersion) }
        guard let type = MessageType(rawValue: wire.type) else { throw .unknownType(wire.type) }
        return EnvelopeHeader(
            protocolVersion: wire.protocolVersion, messageId: wire.messageId, connectorId: wire.connectorId,
            connectionEpoch: wire.connectionEpoch, sequence: wire.sequence, type: type, sentAt: wire.sentAt
        )
    }
}
