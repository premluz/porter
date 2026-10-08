import Foundation
@testable import ConversationCore

/// Plays the connector side of the protocol against a coordinator, with a controllable clock.
struct BridgeHarness {
    var coordinator = BridgeCoordinator(deviceId: UUID(), activationTimeout: 5)
    var now = Sample.start
    private var nextSequence: [ConnectionID: Int] = [:]
    private(set) var sent: [Outbound] = []
    private(set) var events: [BridgeEvent] = []

    struct Client {
        let connection: ConnectionID
        let installationId: UUID
        let epoch: String
        var kind: ConnectorKind = .chrome
        var connectorId: String { BridgeCoordinator.connectorId(for: installationId, kind: kind) }
    }

    static func client(_ id: UInt64, epoch: String = "epoch-1") -> Client {
        Client(connection: ConnectionID(id), installationId: UUID(), epoch: epoch)
    }

    @discardableResult
    mutating func send(
        _ client: Client, type: String, payload: String, sequence: Int? = nil,
        connectorId: String? = nil, epoch: String? = nil, version: String = "1.0"
    ) -> BridgeResult {
        let sequenceNumber = sequence ?? nextSequence[client.connection, default: 0]
        nextSequence[client.connection] = sequenceNumber + 1
        let json = """
        {"protocolVersion":"\(version)","messageId":"\(UUID().uuidString)","connectorId":"\(connectorId ?? client.connectorId)",\
        "connectionEpoch":"\(epoch ?? client.epoch)","sequence":\(sequenceNumber),"type":"\(type)",\
        "sentAt":"2026-10-08T07:00:00Z","payload":\(payload)}
        """
        return deliver(Data(json.utf8), from: client.connection)
    }

    @discardableResult
    mutating func deliver(_ frame: Data, from connection: ConnectionID) -> BridgeResult {
        let result = coordinator.handle(frame: frame, from: connection, now: now)
        record(result)
        return result
    }

    mutating func record(_ result: BridgeResult) {
        sent += result.outbound
        events += result.events
    }

    @discardableResult
    mutating func hello(_ client: Client, alias: String? = nil, providers: [String] = ["claude"]) -> BridgeResult {
        let aliasJSON = alias.map { #","profileAlias":"\#($0)""# } ?? ""
        let versions = providers.map { #""\#($0)":"0.1.0""# }.joined(separator: ",")
        return send(client, type: "hello", payload: #"{"installationId":"\#(client.installationId.uuidString)"\#(aliasJSON),"adapterVersions":{\#(versions)}}"#)
    }

    static func editor(_ id: UInt64, epoch: String = "epoch-1") -> Client {
        Client(connection: ConnectionID(id), installationId: UUID(), epoch: epoch, kind: .vscode)
    }

    @discardableResult
    mutating func helloEditor(_ client: Client, folder: String = "Porter", providers: [String] = ["claude-code"]) -> BridgeResult {
        let versions = providers.map { #""\#($0)":"0.1.0""# }.joined(separator: ",")
        return send(client, type: "hello", payload: #"{"installationId":"\#(client.installationId.uuidString)","profileAlias":"\#(folder)","connectorKind":"vscode","adapterVersions":{\#(versions)}}"#)
    }

    /// Each entry is (conversation id, title, workspace path, column, index).
    @discardableResult
    mutating func editorSnapshot(
        _ client: Client, tabs: [(id: String, title: String, path: String, column: Int, index: Int)], provider: String = "claude-code"
    ) -> BridgeResult {
        let list = tabs.map {
            #"{"provider":"\#(provider)","providerConversationId":"\#($0.id)","title":"\#($0.title)","workspacePath":"\#($0.path)","viewColumn":\#($0.column),"index":\#($0.index)}"#
        }.joined(separator: ",")
        return send(client, type: "inventory.snapshot", payload: #"{"tabs":[],"editorTabs":[\#(list)]}"#)
    }

    @discardableResult
    mutating func snapshot(_ client: Client, tabs: [(tab: Int, window: Int, chat: String, title: String)]) -> BridgeResult {
        let list = tabs.map {
            #"{"tabId":\#($0.tab),"windowId":\#($0.window),"provider":"claude","providerConversationId":"\#($0.chat)","title":"\#($0.title)","canonicalUrl":"https://claude.ai/chat/\#($0.chat)"}"#
        }.joined(separator: ",")
        return send(client, type: "inventory.snapshot", payload: #"{"tabs":[\#(list)]}"#)
    }

    /// Frames the coordinator sent to one connection, decoded back through the real decoder.
    func messages(to connection: ConnectionID) throws -> [BridgeMessage] {
        try sent.filter { $0.connection == connection }.compactMap { outbound in
            if case .send(let data) = outbound.action { return try EnvelopeDecoder.decodeMessage(data) }
            return nil
        }
    }

    func wasClosed(_ connection: ConnectionID) -> Bool {
        sent.contains { $0.connection == connection && $0.action == .close }
    }

    func errorCodes(to connection: ConnectionID) throws -> [BridgeErrorCode] {
        try messages(to: connection).compactMap { message in
            if case .error(let error) = message.body { return error.code }
            return nil
        }
    }
}
