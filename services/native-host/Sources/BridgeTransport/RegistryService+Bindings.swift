import ConversationCore
import Foundation

extension RegistryService {
    /// Reads the saved ties between agent sessions and tabs. A missing file is a first run; one that cannot be read is
    /// said so in the log and ignored, because a tie is only a convenience and a wrong one is worse than none.
    func loadBindings() {
        guard let path = bindingsPath, FileManager.default.fileExists(atPath: path) else { return }
        do {
            let stored = try ContractCoding.decoder().decode([String: AgentBinding].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            coordinator.withLock { $0.restoreAgentBindings(stored, now: Date()) }
        } catch {
            log("agent ties not restored (\(path)): \(error)")
        }
    }

    func saveBindings() {
        guard let path = bindingsPath else { return }
        let bindings = coordinator.withLock { $0.exportedAgentBindings() }
        do {
            let data = try ContractCoding.encoder().encode(bindings)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        } catch {
            log("agent ties not saved (\(path)): \(error)")
        }
    }
}
