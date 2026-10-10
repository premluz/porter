import ConversationCore
import Foundation
import Synchronization
import Testing
@testable import BridgeTransport

@Suite("The ties between agent sessions and tabs survive Porter restarting")
struct BindingPersistenceTests {
    private func scratch() throws -> String {
        let directory = NSTemporaryDirectory() + "porter-bind-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        return directory
    }

    private func service(path: String?, log: @escaping @Sendable (String) -> Void = { _ in }) -> RegistryService {
        RegistryService(deviceId: UUID(), log: log, focusApplication: { "" }, bindingsPath: path)
    }

    private let binding = AgentBinding(conversationId: "bbbb2222", workspace: "/Users/example/Bastion", boundAt: Date())

    @Test("saved ties are read by the next run, and the file is private to the user")
    func roundTrip() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/agent-bindings.json"
        let first = service(path: path)
        first.coordinator.withLock { $0.restoreAgentBindings(["session-1": binding], now: Date()) }
        first.saveBindings()
        let mode = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
        let second = service(path: path)
        #expect(second.coordinator.withLock { $0.exportedAgentBindings() }["session-1"]?.conversationId == "bbbb2222")
    }

    @Test("an unreadable file is reported and ignored; no path means nothing is kept")
    func badFileAndNoPath() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let path = directory + "/agent-bindings.json"
        try Data("not json".utf8).write(to: URL(fileURLWithPath: path))
        let lines = Mutex<[String]>([])
        let broken = service(path: path) { line in lines.withLock { $0.append(line) } }
        #expect(broken.coordinator.withLock { $0.exportedAgentBindings() }.isEmpty)
        #expect(lines.withLock { $0 }.contains { $0.contains("agent ties not restored") })
        let none = service(path: nil)
        none.coordinator.withLock { $0.restoreAgentBindings(["s": binding], now: Date()) }
        none.saveBindings()
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory) == ["agent-bindings.json"])
    }
}
