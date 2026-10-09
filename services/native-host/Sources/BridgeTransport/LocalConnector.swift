import ConversationCore
import Darwin
import Foundation
import Synchronization

private struct ConnectorEnvelope<Payload: Encodable>: Encodable {
    let protocolVersion = "1.0"
    let messageId = UUID()
    let connectorId: String
    let connectionEpoch: String
    let sequence: Int
    let type: String
    let sentAt = Date()
    let payload: Payload
}

private struct NoPayload: Encodable {}

/// Runs a `HostConnector` inside the app and joins it to the registry over the same wire protocol an
/// out-of-process connector uses, through a connected socket pair. The registry therefore cannot tell
/// the difference, and every rule it enforces (hello, sequence, epoch, revision checks) applies as is.
public final class LocalConnectorSession: Sendable {
    static let heartbeatInterval: TimeInterval = 30

    private let connector: any HostConnector
    private let connection: FramedConnection
    private let connectorId: String
    private let epoch = UUID().uuidString
    private let sequence = Mutex(0)
    private let tasks = Mutex<[Task<Void, Never>]>([])
    private let log: @Sendable (String) -> Void

    init(connector: any HostConnector, connection: FramedConnection, log: @escaping @Sendable (String) -> Void) {
        self.connector = connector
        self.connection = connection
        self.connectorId = BridgeCoordinator.connectorId(for: connector.installationId, kind: connector.kind)
        self.log = log
    }

    /// Disconnects from the registry, which then drops this connector's destinations.
    public func stop() {
        tasks.withLock { $0.forEach { $0.cancel() } }
        connection.shutdown()
    }

    func start() {
        let thread = Thread { [self] in readLoop() }
        thread.name = "porter.local-connector"
        thread.start()
    }

    private func readLoop() {
        defer { connection.closeDescriptor() }
        do {
            try send("hello", HelloPayload(
                installationId: connector.installationId, profileAlias: connector.profileAlias,
                connectorKind: connector.kind, adapterVersions: connector.adapterVersions
            ))
            while let frame = try connection.receive(maximumBytes: EnvelopeDecoder.maximumBytes) {
                handle(try EnvelopeDecoder.decodeMessage(frame))
            }
        } catch {
            log("local connector \(connectorId) ended: \(error)")
        }
    }

    private func handle(_ message: BridgeMessage) {
        switch message.body {
        case .helloAck(let ack):
            guard ack.accepted else { log("local connector \(connectorId) refused by the registry"); stop(); return }
            beginWork()
        case .snapshotRequest:
            run { await $0.sendSnapshot() }
        case .activateRequest(let request):
            run { await $0.activate(request) }
        case .error(let error):
            log("local connector \(connectorId): registry reported \(error.code.rawValue): \(error.message)")
        default:
            log("local connector \(connectorId): ignored \(message.body.type.rawValue)")
        }
    }

    private func beginWork() {
        run { await $0.sendSnapshot() }
        run { session in
            for await _ in session.connector.changes() { await session.sendSnapshot() }
        }
        run { session in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.heartbeatInterval))
                if Task.isCancelled { break }
                session.sendOrLog("heartbeat", NoPayload())
            }
        }
    }

    private func run(_ work: @escaping @Sendable (LocalConnectorSession) async -> Void) {
        let task = Task { await work(self) }
        tasks.withLock { $0.append(task) }
    }

    private func sendSnapshot() async {
        do {
            sendOrLog("inventory.snapshot", try await connector.snapshot())
        } catch {
            log("local connector \(connectorId): snapshot failed: \(error)")
        }
    }

    private func activate(_ request: ActivateRequestPayload) async {
        let outcome = await connector.activate(request)
        sendOrLog("activate.result", ActivationResult(
            requestId: request.requestId, destinationId: request.destinationId,
            destinationRevision: request.destinationRevision, outcome: outcome
        ))
    }

    private func sendOrLog<Payload: Encodable>(_ type: String, _ payload: Payload) {
        do { try send(type, payload) } catch { log("local connector \(connectorId): send \(type) failed: \(error)") }
    }

    /// Sequence numbers and writes are taken together, so frames reach the registry in numbered order.
    private func send<Payload: Encodable>(_ type: String, _ payload: Payload) throws {
        try sequence.withLock { next in
            let envelope = ConnectorEnvelope(
                connectorId: connectorId, connectionEpoch: epoch, sequence: next, type: type, payload: payload
            )
            try connection.send(try ContractCoding.encoder().encode(envelope))
            next += 1
        }
    }
}
