import ConversationCore
import Darwin
import Foundation
import Synchronization

/// Runs the BridgeCoordinator behind two same-user sockets: one for browser connectors (reached
/// through the native-messaging relay) and one for control clients. The coordinator is the single
/// writer; everything here is I/O and thread plumbing around it.
public final class RegistryService: Sendable {
    static let sweepInterval: TimeInterval = 1
    static let waitMargin: TimeInterval = 2

    let coordinator: Mutex<BridgeCoordinator>
    let connections = Mutex<[ConnectionID: FramedConnection]>([:])
    let waiters = Mutex<[UUID: ActivationWaiter]>([:])
    let nextConnection = Atomic<UInt64>(1)
    let activationTimeout: TimeInterval
    let log: @Sendable (String) -> Void
    /// Best-effort bring-the-app-forward step, run after the connector reports success.
    let focusApplication: @Sendable () -> String
    /// Called after the visible list or a connection changes; never with the coordinator locked.
    let onChange: @Sendable () -> Void

    public init(
        deviceId: UUID, activationTimeout: TimeInterval = 5,
        log: @escaping @Sendable (String) -> Void, focusApplication: @escaping @Sendable () -> String,
        onChange: @escaping @Sendable () -> Void = {}
    ) {
        self.coordinator = Mutex(BridgeCoordinator(deviceId: deviceId, activationTimeout: activationTimeout))
        self.activationTimeout = activationTimeout
        self.log = log
        self.focusApplication = focusApplication
        self.onChange = onChange
    }

    /// Binds both sockets, then serves forever on background threads.
    public func start(bridgePath: String, controlPath: String) throws(SocketError) {
        let bridge = try UnixSocket.listen(path: bridgePath)
        let control = try UnixSocket.listen(path: controlPath)
        spawn("bridge-accept") { [self] in acceptLoop(bridge, name: "bridge") { self.serveBridge($0) } }
        spawn("control-accept") { [self] in acceptLoop(control, name: "control") { self.serveControl($0) } }
        spawn("sweeper") { [self] in sweepLoop() }
    }

    func spawn(_ name: String, _ body: @escaping @Sendable () -> Void) {
        let thread = Thread(block: body)
        thread.name = "porter.\(name)"
        thread.start()
    }

    private func acceptLoop(_ listener: Int32, name: String, serve: @escaping @Sendable (FramedConnection) -> Void) {
        while true {
            do {
                let fd = try UnixSocket.accept(listener: listener)
                let connection = FramedConnection(fd: fd)
                spawn("\(name)-conn") { serve(connection) }
            } catch {
                log("\(name): rejected connection: \(error)")
            }
        }
    }

    private func sweepLoop() {
        while true {
            Thread.sleep(forTimeInterval: Self.sweepInterval)
            apply(coordinator.withLock { $0.sweep(now: Date()) })
        }
    }

    private func serveBridge(_ connection: FramedConnection) {
        let id = ConnectionID(nextConnection.wrappingAdd(1, ordering: .relaxed).oldValue)
        connections.withLock { $0[id] = connection }
        defer {
            connections.withLock { $0[id] = nil }
            apply(coordinator.withLock { $0.disconnect(id, now: Date()) })
            connection.closeDescriptor()
        }
        do {
            while let frame = try connection.receive(maximumBytes: EnvelopeDecoder.maximumBytes) {
                apply(coordinator.withLock { $0.handle(frame: frame, from: id, now: Date()) })
            }
        } catch {
            log("bridge \(id): closed by transport error: \(error)")
        }
    }

    /// Performs sends and closes, logs events, and hands activation outcomes to waiting callers.
    func apply(_ result: BridgeResult) {
        for outbound in result.outbound {
            guard let connection = connections.withLock({ $0[outbound.connection] }) else { continue }
            switch outbound.action {
            case .send(let data):
                do { try connection.send(data) } catch { log("send to \(outbound.connection) failed: \(error)") }
            case .close:
                connection.shutdown()
            }
        }
        for event in result.events { handle(event) }
    }

    private func handle(_ event: BridgeEvent) {
        switch event {
        case .connectorConnected(let id):
            log("connector connected: \(id)")
            onChange()
        case .connectorDisconnected(let id):
            log("connector disconnected: \(id)")
            onChange()
        case .inventoryChanged(let id):
            log("inventory changed: \(id)")
            onChange()
        case .protocolViolation(let connection, let code, let detail): log("violation \(connection) \(code): \(detail)")
        case .activation(let result):
            log("activation \(result.requestId): \(result.outcome)")
            waiters.withLock { $0[result.requestId] }?.fulfill(result)
        }
    }
}
