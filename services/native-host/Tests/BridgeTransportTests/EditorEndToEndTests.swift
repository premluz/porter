import ConversationCore
import Darwin
import Foundation
import Synchronization
import Testing
@testable import BridgeTransport

/// Plays an editor window's companion: connects straight to the registry socket, with no relay.
final class FakeEditor {
    let installationId = UUID()
    private let connection: FramedConnection
    private var sequence = 0
    var connectorId: String { BridgeCoordinator.connectorId(for: installationId, kind: .vscode) }

    init(socketPath: String) throws {
        connection = FramedConnection(fd: try UnixSocket.connect(path: socketPath))
    }

    func send(type: String, payload: String) throws {
        let json = """
        {"protocolVersion":"1.0","messageId":"\(UUID().uuidString)","connectorId":"\(connectorId)",\
        "connectionEpoch":"epoch-1","sequence":\(sequence),"type":"\(type)","sentAt":"2026-10-08T07:00:00Z","payload":\(payload)}
        """
        sequence += 1
        try connection.send(Data(json.utf8))
    }

    func hello(folder: String) throws {
        try send(type: "hello", payload: #"{"installationId":"\#(installationId.uuidString)","profileAlias":"\#(folder)","connectorKind":"vscode","adapterVersions":{"claude-code":"0.1.0"}}"#)
    }

    func snapshot(path: String, title: String) throws {
        try send(type: "inventory.snapshot", payload: #"{"tabs":[],"editorTabs":[{"provider":"claude-code","providerConversationId":"aaaa1111","title":"\#(title)","workspacePath":"\#(path)","viewColumn":1,"index":0}]}"#)
    }

    func receive(timeout: TimeInterval = 3) -> BridgeMessage? {
        var descriptor = pollfd(fd: connection.fd, events: Int16(POLLIN), revents: 0)
        guard poll(&descriptor, 1, Int32(timeout * 1000)) > 0,
              let frame = try? connection.receive(maximumBytes: 1 << 20) else { return nil }
        return try? EnvelopeDecoder.decodeMessage(frame)
    }

    func close() { connection.closeDescriptor() }
}

/// Collects what the host was asked to prepare, safely from the registry's threads.
final class PreparedLog: Sendable {
    private let items = Mutex<[ActivationPreparation]>([])

    func add(_ preparation: ActivationPreparation) { items.withLock { $0.append(preparation) } }

    var all: [ActivationPreparation] { items.withLock { $0 } }
}

@Suite("An editor window through the real socket", .serialized)
struct EditorEndToEndTests {
    private func start(prepared: PreparedLog) throws -> String {
        let directory = NSTemporaryDirectory() + "porter-ed-\(UInt32.random(in: 0...UInt32.max))"
        #expect(mkdir(directory, 0o700) == 0)
        let service = RegistryService(
            deviceId: UUID(), activationTimeout: 2, log: { _ in }, focusApplication: { "browserForward" },
            prepareActivation: { preparation in
                prepared.add(preparation)
                return "stubbedPrepare"
            },
            windowSettleDelay: 0.05
        )
        try service.start(bridgePath: directory + "/bridge.sock", controlPath: directory + "/control.sock")
        return directory
    }

    private func control(_ directory: String, _ request: ControlRequest) throws -> ControlResponse {
        let connection = FramedConnection(fd: try UnixSocket.connect(path: directory + "/control.sock"))
        defer { connection.closeDescriptor() }
        try connection.send(try JSONEncoder().encode(request))
        let reply = try #require(try connection.receive(maximumBytes: ControlLimits.maximumResponseBytes))
        return try JSONDecoder().decode(ControlResponse.self, from: reply)
    }

    private func waitForRows(_ directory: String, count: Int) throws -> [DestinationRow] {
        for _ in 0..<100 {
            let rows = try control(directory, ControlRequest(command: .list)).rows ?? []
            if rows.count == count { return rows }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return try control(directory, ControlRequest(command: .list)).rows ?? []
    }

    @Test("a window's tab is listed, the window is prepared first, and the connector's answer decides the outcome")
    func activationRoundTrip() throws {
        let prepared = PreparedLog()
        let directory = try start(prepared: prepared)
        let editor = try FakeEditor(socketPath: directory + "/bridge.sock")
        defer { editor.close() }
        try editor.hello(folder: "Porter")
        #expect(editor.receive()?.body == .helloAck(HelloAckPayload(accepted: true, connectorId: editor.connectorId)))
        try editor.snapshot(path: "/Users/example/Porter", title: "Release plan")
        let row = try #require(try waitForRows(directory, count: 1).first)
        #expect(row.provider == "claude-code" && row.profileAlias == "Porter")

        let answer = Thread {
            guard let message = editor.receive(), case .activateRequest(let request) = message.body else { return }
            // At this point the host must already have prepared the window.
            let result = #"{"requestId":"\#(request.requestId)","destinationId":"\#(request.destinationId)","destinationRevision":\#(request.destinationRevision),"outcome":"activated"}"#
            try? editor.send(type: "activate.result", payload: result)
        }
        answer.start()
        let response = try control(directory, ControlRequest(command: .activate, destinationId: row.destinationId, revision: row.revision))
        #expect(response.outcome == .activated)
        #expect(response.appActivation == "stubbedPrepare")
        #expect(prepared.all == [ActivationPreparation(bundleId: "com.microsoft.VSCode", workspacePath: "/Users/example/Porter")])
    }

    @Test("a window that never answers reports a timeout and claims nothing")
    func silentWindow() throws {
        let directory = try start(prepared: PreparedLog())
        let editor = try FakeEditor(socketPath: directory + "/bridge.sock")
        defer { editor.close() }
        try editor.hello(folder: "Porter")
        _ = editor.receive()
        try editor.snapshot(path: "/Users/example/Porter", title: "Notes")
        let row = try #require(try waitForRows(directory, count: 1).first)
        let response = try control(directory, ControlRequest(command: .activate, destinationId: row.destinationId, revision: row.revision))
        #expect(response.outcome == .timeout)
        #expect(response.appActivation == nil)
    }

    @Test("an editor that is not answering as the browser does not get a browser focus step")
    func noBrowserFocusForEditors() throws {
        let prepared = PreparedLog()
        let directory = try start(prepared: prepared)
        let editor = try FakeEditor(socketPath: directory + "/bridge.sock")
        defer { editor.close() }
        try editor.hello(folder: "Porter")
        _ = editor.receive()
        try editor.snapshot(path: "/Users/example/Porter", title: "Notes")
        let row = try #require(try waitForRows(directory, count: 1).first)
        let answer = Thread {
            guard let message = editor.receive(), case .activateRequest(let request) = message.body else { return }
            let refusal = #"{"requestId":"\#(request.requestId)","destinationId":"\#(request.destinationId)","destinationRevision":\#(request.destinationRevision),"outcome":"targetChanged"}"#
            try? editor.send(type: "activate.result", payload: refusal)
        }
        answer.start()
        let response = try control(directory, ControlRequest(command: .activate, destinationId: row.destinationId, revision: row.revision))
        #expect(response.outcome == .targetChanged)
        #expect(response.appActivation == nil)
    }
}
