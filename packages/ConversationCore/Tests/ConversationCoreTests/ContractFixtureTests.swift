import Foundation
import Testing
@testable import ConversationCore

@Suite("Shared contract fixtures decode into Swift models")
struct ContractFixtureTests {
    private static let decoders: [String: @Sendable (Data) throws -> Void] = [
        "conversation": { _ = try ContractCoding.decoder().decode(Conversation.self, from: $0) },
        "account-scope": { _ = try ContractCoding.decoder().decode(AccountScope.self, from: $0) },
        "connector": { _ = try ContractCoding.decoder().decode(Connector.self, from: $0) },
        "destination": { _ = try ContractCoding.decoder().decode(Destination.self, from: $0) },
        "status-observation": { _ = try ContractCoding.decoder().decode(StatusObservation.self, from: $0) },
        "envelope": { _ = try EnvelopeDecoder.decodeHeader($0) },
        "activation-result": { _ = try ContractCoding.decoder().decode(ActivationResult.self, from: $0) },
        "context-link": { _ = try ContractCoding.decoder().decode(ContextLink.self, from: $0) },
        "bridge-payload": { _ = try BridgePayloadFixture.decode($0) },
        "context-packet": { _ = try ContextPacketDecoder.decode($0) },
    ]

    @Test("every valid fixture directory has a Swift decoder and decodes")
    func everyValidFixtureDecodes() throws {
        let schemas = try FileManager.default.contentsOfDirectory(atPath: ContractFixtures.validRoot.path)
        #expect(Set(schemas) == Set(Self.decoders.keys))
        for schema in schemas {
            let decode = try #require(Self.decoders[schema])
            for file in try ContractFixtures.files(schema) {
                try decode(try Data(contentsOf: file))
            }
        }
    }

    @Test("locator round-trips through its kind discriminator")
    func locatorRoundTrip() throws {
        let destination = try ContractFixtures.decode(Destination.self, "destination", "desktop-link")
        let data = try ContractCoding.encoder().encode(destination)
        let decoded = try ContractCoding.decoder().decode(Destination.self, from: data)
        #expect(decoded == destination)
        #expect(decoded.kind == .desktopLink)
    }

    @Test("unknown suite reference contract is rejected")
    func unknownReferenceContract() throws {
        let json = #"{"contract":"suite-ref/2","type":"manager.task","id":"t-1"}"#
        #expect(throws: DecodingError.self) {
            try ContractCoding.decoder().decode(SuiteReference.self, from: Data(json.utf8))
        }
    }
}
