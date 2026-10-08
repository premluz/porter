import Foundation
@testable import ConversationCore

/// Shared contract fixtures live beside the schemas so Swift and the JSON Schema
/// validator are held to the same examples.
enum ContractFixtures {
    static let validRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../../contracts/fixtures/valid")
        .standardizedFileURL

    static func files(_ schema: String) throws -> [URL] {
        try FileManager.default
            .contentsOfDirectory(at: validRoot.appending(path: schema), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
    }

    static func decode<T: Decodable>(_ type: T.Type, _ schema: String, _ name: String) throws -> T {
        let data = try Data(contentsOf: validRoot.appending(path: "\(schema)/\(name).json"))
        return try ContractCoding.decoder().decode(type, from: data)
    }
}

enum Sample {
    static let start = Date(timeIntervalSince1970: 1_791_450_000)

    static func observation(
        destinationId: UUID = UUID(), activity: Activity = .working, attention: Attention = .none,
        evidence: EvidenceKind = .domSignal, sequence: Int = 1, epoch: String = "epoch-1",
        receivedAt: Date = start, lifetime: TimeInterval = 15, pageClockOffset: TimeInterval = 0
    ) -> StatusObservation {
        let observedAt = start.addingTimeInterval(pageClockOffset)
        return StatusObservation(
            id: UUID(), destinationId: destinationId, activity: activity, attention: attention,
            evidenceKind: evidence, observedAt: observedAt, receivedAt: receivedAt,
            expiresAt: observedAt.addingTimeInterval(lifetime), sequence: sequence,
            connectionEpoch: epoch, adapterVersion: "0.1.0"
        )
    }

    static func tab(
        id: UUID = UUID(), conversationId: UUID = UUID(), connectorId: String = "chrome-personal",
        identityEpoch: String = "identity-1", revision: Int = 1, url: String = "https://claude.ai/chat/fixture"
    ) -> Destination {
        let locator = BrowserTabLocator(
            connectorId: connectorId, connectionEpoch: "epoch-1", tabId: 1, windowIdHint: nil, canonicalUrl: url
        )
        return Destination(
            id: id, conversationId: conversationId, deviceId: UUID(), connectorId: connectorId,
            identityEpoch: identityEpoch, locator: .browserTab(locator), capabilities: [],
            lastVerifiedAt: start, revision: revision
        )
    }
}

/// Bridge payload fixtures share one directory; the file name prefix says which payload type they are.
enum BridgePayloadFixture {
    struct UnknownFixture: Error {}

    static func decode(_ data: Data) throws {
        let decoder = ContractCoding.decoder()
        let attempts: [(Data) throws -> Void] = [
            { _ = try decoder.decode(HelloPayload.self, from: $0) },
            { _ = try decoder.decode(HelloAckPayload.self, from: $0) },
            { _ = try decoder.decode(InventorySnapshotPayload.self, from: $0) },
            { _ = try decoder.decode(DestinationUpsertPayload.self, from: $0) },
            { _ = try decoder.decode(DestinationRemovePayload.self, from: $0) },
            { _ = try decoder.decode(ActivateRequestPayload.self, from: $0) },
            { _ = try decoder.decode(BridgeErrorPayload.self, from: $0) },
        ]
        // EmptyPayload decodes any object, so an empty payload is only valid when it really is empty.
        let isEmptyObject = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?.isEmpty == true
        guard isEmptyObject || attempts.contains(where: { (try? $0(data)) != nil }) else { throw UnknownFixture() }
    }
}
