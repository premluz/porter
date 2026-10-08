import Foundation
import Testing
@testable import ConversationCore

@Suite("Bridge envelope and event ordering")
struct BridgeTests {
    private func envelope(version: String = "1.0", type: String = "hello", padding: Int = 0) -> Data {
        let pad = String(repeating: "x", count: padding)
        let json = """
        {"protocolVersion":"\(version)","messageId":"6f1c2a3e-7777-4a1a-8a1a-000000000001",\
        "connectorId":"chrome-personal","connectionEpoch":"epoch-1","sequence":0,"type":"\(type)",\
        "sentAt":"2026-10-08T07:00:00.250Z","payload":{"pad":"\(pad)"}}
        """
        return Data(json.utf8)
    }

    @Test("a valid envelope header decodes, including fractional seconds")
    func validHeader() throws {
        let header = try EnvelopeDecoder.decodeHeader(envelope(type: "status.observed"))
        #expect(header.type == .statusObserved)
    }

    @Test("an oversized frame is rejected before decoding")
    func oversizedRejected() {
        let data = envelope(padding: EnvelopeDecoder.maximumBytes)
        #expect(throws: EnvelopeRejection.oversized(bytes: data.count)) { try EnvelopeDecoder.decodeHeader(data) }
    }

    @Test("an unknown major version is rejected")
    func unknownMajorRejected() {
        #expect(throws: EnvelopeRejection.unsupportedMajorVersion("2.0")) {
            try EnvelopeDecoder.decodeHeader(envelope(version: "2.0"))
        }
    }

    @Test("an unknown message type is rejected, including send-like types")
    func unknownTypeRejected() {
        #expect(throws: EnvelopeRejection.unknownType("prompt.send")) {
            try EnvelopeDecoder.decodeHeader(envelope(type: "prompt.send"))
        }
    }

    @Test("malformed JSON is rejected with context")
    func malformedRejected() {
        #expect(throws: EnvelopeRejection.self) { try EnvelopeDecoder.decodeHeader(Data("{".utf8)) }
    }

    @Test("sequencer accepts in order, drops replays and stale epochs, reports gaps")
    func sequencing() {
        var sequencer = EventSequencer()
        #expect(sequencer.admit(connectorId: "c", epoch: "e1", sequence: 0) == .unknownConnector)
        sequencer.begin(connectorId: "c", epoch: "e1")
        #expect(sequencer.admit(connectorId: "c", epoch: "e1", sequence: 0) == .accepted)
        #expect(sequencer.admit(connectorId: "c", epoch: "e1", sequence: 0) == .duplicate)
        #expect(sequencer.admit(connectorId: "c", epoch: "e1", sequence: 3) == .gap(expected: 1, received: 3))
        #expect(sequencer.admit(connectorId: "c", epoch: "e1", sequence: 4) == .accepted)
        sequencer.begin(connectorId: "c", epoch: "e2")
        #expect(sequencer.admit(connectorId: "c", epoch: "e1", sequence: 5) == .staleEpoch)
        #expect(sequencer.admit(connectorId: "c", epoch: "e2", sequence: 0) == .accepted)
    }
}
