import Foundation
import Testing
@testable import ConversationCore

@Suite("Bridge handshake and forged input (TEST-011)")
struct BridgeHandshakeTests {
    @Test("hello is acknowledged and opens the connector")
    func helloAccepted() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client, alias: "Personal")
        let ack = try harness.messages(to: client.connection).first
        #expect(ack?.body == .helloAck(HelloAckPayload(accepted: true, connectorId: client.connectorId)))
        #expect(harness.events.contains(.connectorConnected(connectorId: client.connectorId)))
    }

    @Test("messages before hello are refused and the connection closed")
    func beforeHello() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[]}"#, sequence: 0)
        #expect(try harness.errorCodes(to: client.connection) == [.outOfOrder])
        #expect(harness.wasClosed(client.connection))
    }

    @Test("malformed JSON, unknown versions and unknown types close the connection")
    func malformedInput() throws {
        let cases: [(String, Data, BridgeErrorCode)] = [
            ("malformed", Data("{".utf8), .malformed),
            ("oversized", Data(repeating: 0x20, count: EnvelopeDecoder.maximumBytes + 1), .malformed),
        ]
        for (name, frame, code) in cases {
            var harness = BridgeHarness()
            harness.deliver(frame, from: ConnectionID(9))
            #expect(try harness.errorCodes(to: ConnectionID(9)) == [code], "\(name)")
            #expect(harness.wasClosed(ConnectionID(9)), "\(name)")
        }
        var versioned = BridgeHarness()
        let client = BridgeHarness.client(1)
        versioned.send(client, type: "hello", payload: "{}", version: "2.0")
        #expect(try versioned.errorCodes(to: client.connection) == [.unsupportedVersion])
        var typed = BridgeHarness()
        typed.send(client, type: "prompt.send", payload: "{}")
        #expect(try typed.errorCodes(to: client.connection) == [.malformed])
    }

    @Test("a connectorId that does not derive from the installation ID is refused")
    func forgedConnectorOnHello() throws {
        var harness = BridgeHarness()
        let victim = BridgeHarness.client(1)
        let attacker = BridgeHarness.client(2)
        harness.send(attacker, type: "hello", payload: #"{"installationId":"\#(attacker.installationId)","adapterVersions":{"claude":"0.1.0"}}"#, connectorId: victim.connectorId)
        #expect(try harness.errorCodes(to: attacker.connection) == [.unauthorized])
        #expect(harness.wasClosed(attacker.connection))
    }

    @Test("a second live connection with the same installation ID is refused; the first keeps working")
    func duplicateInstallation() throws {
        var harness = BridgeHarness()
        let first = BridgeHarness.client(1)
        harness.hello(first)
        let clone = BridgeHarness.Client(connection: ConnectionID(2), installationId: first.installationId, epoch: "epoch-2")
        harness.hello(clone)
        #expect(try harness.errorCodes(to: clone.connection) == [.duplicateInstallation])
        #expect(harness.wasClosed(clone.connection))
        harness.snapshot(first, tabs: [(1, 1, "chat-a", "A")])
        #expect(harness.coordinator.rows().count == 1)
    }

    @Test("later messages must carry the bound connector and epoch")
    func forgedAfterHello() throws {
        var harness = BridgeHarness()
        let personal = BridgeHarness.client(1)
        let work = BridgeHarness.client(2)
        harness.hello(personal)
        harness.hello(work)
        harness.send(personal, type: "inventory.snapshot", payload: #"{"tabs":[]}"#, connectorId: work.connectorId)
        #expect(try harness.errorCodes(to: personal.connection) == [.unauthorized])
        #expect(harness.wasClosed(personal.connection))
        harness.send(work, type: "heartbeat", payload: "{}", epoch: "other-epoch")
        #expect(harness.wasClosed(work.connection))
    }

    @Test("registry-only message types from a connector are refused")
    func registryOnlyTypes() throws {
        for type in ["activate.request", "snapshot.request", "hello.ack"] {
            var harness = BridgeHarness()
            let client = BridgeHarness.client(1)
            harness.hello(client)
            let payload = type == "hello.ack" ? #"{"accepted":true}"# : "{}"
            harness.send(client, type: type, payload: payload)
            #expect(harness.wasClosed(client.connection), "\(type)")
        }
    }

    @Test("a replayed sequence is dropped without effect")
    func replayDropped() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client)
        harness.snapshot(client, tabs: [(1, 1, "chat-a", "A")])
        harness.snapshot(client, tabs: [], )
        let before = harness.coordinator.rows()
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[{"tabId":9,"windowId":1,"provider":"claude","providerConversationId":"evil","title":"E","canonicalUrl":"https://claude.ai/chat/evil"}]}"#, sequence: 1)
        #expect(harness.coordinator.rows() == before)
    }

    @Test("a sequence gap applies the event and asks for a snapshot")
    func gapRequestsSnapshot() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client)
        harness.send(client, type: "heartbeat", payload: "{}", sequence: 5)
        let types = try harness.messages(to: client.connection).map(\.header.type)
        #expect(types.contains(.snapshotRequest))
        #expect(!harness.wasClosed(client.connection))
    }

    @Test("a connector cannot report a provider it did not declare")
    func undeclaredProvider() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client, providers: ["claude"])
        harness.send(client, type: "inventory.snapshot", payload: #"{"tabs":[{"tabId":1,"windowId":1,"provider":"chatgpt","providerConversationId":"x","title":"T","canonicalUrl":"https://chatgpt.com/c/x"}]}"#)
        #expect(try harness.errorCodes(to: client.connection) == [.unauthorized])
        #expect(harness.coordinator.rows().isEmpty)
    }

    @Test("snapshot limits and non-https URLs are rejected")
    func snapshotLimits() throws {
        var harness = BridgeHarness()
        let client = BridgeHarness.client(1)
        harness.hello(client)
        let tabs = (0...BridgeLimits.maximumTabsPerSnapshot).map { (tab: $0, window: 1, chat: "c\($0)", title: "t") }
        harness.snapshot(client, tabs: tabs)
        #expect(harness.wasClosed(client.connection))
        var plain = BridgeHarness()
        plain.hello(client)
        plain.send(client, type: "destination.upsert", payload: #"{"tab":{"tabId":1,"windowId":1,"provider":"claude","providerConversationId":"x","title":"T","canonicalUrl":"http://claude.ai/chat/x"}}"#)
        #expect(plain.coordinator.rows().isEmpty)
        #expect(try plain.errorCodes(to: client.connection) == [.malformed])
    }
}
