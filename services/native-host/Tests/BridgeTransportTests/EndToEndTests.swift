import ConversationCore
import Darwin
import Foundation
import Testing
@testable import BridgeTransport

@Suite("Two simulated Chrome profiles through the real relay and registry", .serialized)
struct EndToEndTests {
    private struct Environment {
        let directory: String
        let service: RegistryService
    }

    private func start(focus: String = "stubbed") throws -> Environment {
        let directory = NSTemporaryDirectory() + "porter-e2e-\(UInt32.random(in: 0...UInt32.max))"
        #expect(mkdir(directory, 0o700) == 0)
        try FakeChrome.origin.write(toFile: directory + "/allowed-origins.txt", atomically: true, encoding: .utf8)
        let service = RegistryService(deviceId: UUID(), activationTimeout: 2, log: { _ in }, focusApplication: { focus })
        try service.start(bridgePath: directory + "/bridge.sock", controlPath: directory + "/control.sock")
        return Environment(directory: directory, service: service)
    }

    private func control(_ environment: Environment, _ request: ControlRequest) throws -> ControlResponse {
        let connection = FramedConnection(fd: try UnixSocket.connect(path: environment.directory + "/control.sock"))
        defer { connection.closeDescriptor() }
        try connection.send(try JSONEncoder().encode(request))
        let reply = try #require(try connection.receive(maximumBytes: ControlLimits.maximumResponseBytes))
        return try JSONDecoder().decode(ControlResponse.self, from: reply)
    }

    private func connect(_ environment: Environment, alias: String, window: Int) throws -> FakeChrome {
        let chrome = try FakeChrome(supportDirectory: environment.directory)
        try chrome.hello(alias: alias)
        let ack = try #require(chrome.receive())
        #expect(ack.body == .helloAck(HelloAckPayload(accepted: true, connectorId: chrome.connectorId)))
        try chrome.snapshot(tabId: 42, windowId: window, chat: "chat-a", title: "Release plan")
        return chrome
    }

    private func waitForRows(_ environment: Environment, count: Int) throws -> [DestinationRow] {
        for _ in 0..<100 {
            let rows = try control(environment, ControlRequest(command: .list)).rows ?? []
            if rows.count == count { return rows }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return try control(environment, ControlRequest(command: .list)).rows ?? []
    }

    @Test("identical titles in two profiles stay separate and activation reaches only the chosen profile")
    func twoProfilesActivation() throws {
        let environment = try start()
        let personal = try connect(environment, alias: "Personal", window: 7)
        let work = try connect(environment, alias: "Work", window: 3)
        defer { personal.terminate(); work.terminate() }
        let rows = try waitForRows(environment, count: 2)
        #expect(rows.map(\.profileAlias) == ["Personal", "Work"])
        #expect(Set(rows.map(\.conversationId)).count == 2)
        let target = try #require(rows.first { $0.profileAlias == "Work" })

        let personalReply = Thread { _ = personal.receive(timeout: 1.5) }
        personalReply.start()
        let answer = Thread {
            guard let message = work.receive(), case .activateRequest(let request) = message.body else { return }
            let result = #"{"requestId":"\#(request.requestId)","destinationId":"\#(request.destinationId)","destinationRevision":\#(request.destinationRevision),"outcome":"activated"}"#
            try? work.send(type: "activate.result", payload: result)
        }
        answer.start()
        let response = try control(environment, ControlRequest(command: .activate, destinationId: target.destinationId, revision: target.revision))
        #expect(response.outcome == .activated)
        #expect(response.appActivation == "stubbed")
    }

    @Test("an unanswered activation reports timeout and does not claim success")
    func silentConnector() throws {
        let environment = try start()
        let chrome = try connect(environment, alias: "Personal", window: 1)
        defer { chrome.terminate() }
        let target = try #require(try waitForRows(environment, count: 1).first)
        let response = try control(environment, ControlRequest(command: .activate, destinationId: target.destinationId, revision: target.revision))
        #expect(response.outcome == .timeout)
        #expect(response.appActivation == nil)
    }

    @Test("a forged connectorId gets an error and the relay ends")
    func forgedMessage() throws {
        let environment = try start()
        let victim = try connect(environment, alias: "Work", window: 1)
        let attacker = try connect(environment, alias: "Personal", window: 2)
        defer { victim.terminate(); attacker.terminate() }
        try attacker.send(type: "inventory.snapshot", payload: #"{"tabs":[]}"#, connectorId: victim.connectorId)
        let reply = try #require(attacker.receive())
        guard case .error(let error) = reply.body else { Issue.record("expected error, got \(reply.body)"); return }
        #expect(error.code == .unauthorized)
        #expect(attacker.waitForExit(timeout: 3) == 0)
        // The forged empty snapshot must not have wiped the victim's tabs.
        let victimRows = try waitForRows(environment, count: 2).filter { $0.profileAlias == "Work" }
        #expect(victimRows.count == 1)
        #expect(victimRows.first?.reachability == .connected)
    }

    @Test("closing a profile disconnects it; its route remains visible but disconnected")
    func profileClosed() throws {
        let environment = try start()
        let chrome = try connect(environment, alias: "Personal", window: 1)
        _ = try waitForRows(environment, count: 1)
        chrome.terminate()
        _ = chrome.waitForExit(timeout: 3)
        for _ in 0..<100 {
            let rows = try control(environment, ControlRequest(command: .list)).rows ?? []
            if rows.first?.reachability == .disconnected { return }
            Thread.sleep(forTimeInterval: 0.02)
        }
        Issue.record("route never became disconnected")
    }

    @Test("an origin outside the allowlist is refused before any traffic")
    func unapprovedOrigin() throws {
        let environment = try start()
        let rogue = try FakeChrome(supportDirectory: environment.directory, origin: "chrome-extension://ponmlkjihgfedcbaponmlkjihgfedcba/")
        #expect(rogue.waitForExit(timeout: 3) == 2)
    }

    @Test("a second process with the same installation ID is refused while the first keeps working")
    func duplicateInstallation() throws {
        let environment = try start()
        let first = try connect(environment, alias: "Personal", window: 1)
        let clone = try FakeChrome(supportDirectory: environment.directory, epoch: "epoch-2")
        defer { first.terminate(); clone.terminate() }
        try clone.send(type: "hello", payload: #"{"installationId":"\#(first.installationId.uuidString)","adapterVersions":{"claude":"0.1.0"}}"#, connectorId: first.connectorId)
        guard let reply = clone.receive(), case .error(let error) = reply.body else { Issue.record("no error reply"); return }
        #expect(error.code == .duplicateInstallation)
        #expect(try waitForRows(environment, count: 1).first?.reachability == .connected)
    }
}
