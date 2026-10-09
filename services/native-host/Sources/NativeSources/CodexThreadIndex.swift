import Foundation

public struct CodexThread: Equatable, Sendable {
    public let id: String
    public let title: String
    public let updatedAt: Date
    /// The project folder the thread was started in.
    public let workspacePath: String?
    /// Which Codex surface made it, as Codex records it ("codex_vscode" for the VS Code extension).
    public let originator: String?

    public var startedInVSCode: Bool { originator == "codex_vscode" }
}

/// Codex's own list of threads, read from its local files: the index (id, title, last update) and the first line of
/// each thread's session file (folder, which surface made it, whether it is a helper's thread). Nothing of the
/// conversation is read; the first line also carries instructions, which are parsed past and never kept.
public final class CodexThreadIndex: @unchecked Sendable {
    private struct SessionMeta {
        let workspacePath: String?
        let originator: String?
        let isHelper: Bool
    }

    private let home: String
    private let lock = NSLock()
    private var sessionFiles: [String: String] = [:]
    private var metaCache: [String: SessionMeta] = [:]

    static let firstLineLimit = 4 * 1024 * 1024

    public init(home: String = NSHomeDirectory() + "/.codex") {
        self.home = home
    }

    public var isAvailable: Bool { FileManager.default.fileExists(atPath: indexPath) }

    var indexPath: String { home + "/session_index.jsonl" }

    /// Changes whenever Codex records a thread or an update, so a poller can tell when to look again.
    public func fingerprint() -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: indexPath)
        let size = (attributes?[.size] as? Int) ?? 0
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)|\(modified)"
    }

    /// The threads a person made, newest first, updated within `window` seconds of `now`. Helper threads that Codex
    /// starts for itself (reviewers, sub-agents) are not conversations to go back to and are left out.
    public func recentThreads(now: Date, window: TimeInterval = 7 * 86_400, limit: Int = 40) -> [CodexThread] {
        guard let text = try? String(contentsOfFile: indexPath, encoding: .utf8) else { return [] }
        let formatter = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let plain = Date.ISO8601FormatStyle()
        // The index is appended to as a thread changes, so an id can appear many times; the latest line is the truth.
        var latest: [String: (title: String, updatedAt: Date)] = [:]
        for line in text.split(separator: "\n") {
            guard let object = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any],
                  let id = object["id"] as? String, let stamp = object["updated_at"] as? String,
                  let updated = (try? formatter.parse(stamp)) ?? (try? plain.parse(stamp)),
                  now.timeIntervalSince(updated) <= window else { continue }
            if let known = latest[id], known.updatedAt >= updated { continue }
            latest[id] = ((object["thread_name"] as? String) ?? "", updated)
        }
        let candidates = latest.map { (id: $0.key, title: $0.value.title, updatedAt: $0.value.updatedAt) }
            .sorted { ($0.updatedAt, $0.id) > ($1.updatedAt, $1.id) }
        var threads: [CodexThread] = []
        for candidate in candidates {
            guard threads.count < limit, let meta = meta(for: candidate.id), !meta.isHelper else { continue }
            let title = candidate.title.trimmingCharacters(in: .whitespacesAndNewlines)
            threads.append(CodexThread(
                id: candidate.id, title: title.isEmpty ? "Untitled thread" : String(title.prefix(512)),
                updatedAt: candidate.updatedAt, workspacePath: meta.workspacePath, originator: meta.originator
            ))
        }
        return threads
    }

    private func meta(for id: String) -> SessionMeta? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = metaCache[id] { return cached }
        guard let path = sessionFile(for: id), let meta = Self.readMeta(atPath: path) else { return nil }
        metaCache[id] = meta
        return meta
    }

    /// Session files are named `rollout-<time>-<id>.jsonl` under dated folders; the folder tree is walked again only
    /// when a thread is not in the map.
    private func sessionFile(for id: String) -> String? {
        if let known = sessionFiles[id] { return known }
        let root = home + "/sessions"
        guard let walker = FileManager.default.enumerator(atPath: root) else { return nil }
        for case let relative as String in walker where relative.hasSuffix(".jsonl") {
            let stem = String((relative as NSString).lastPathComponent.dropLast(".jsonl".count))
            // The id is the thread's UUID, the last 36 characters of the name.
            guard stem.hasPrefix("rollout-"), stem.count > 36 else { continue }
            sessionFiles[String(stem.suffix(36))] = root + "/" + relative
        }
        return sessionFiles[id]
    }

    private static func readMeta(atPath path: String) -> SessionMeta? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        var line = Data()
        while line.count < firstLineLimit, let chunk = try? handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
            if let newline = chunk.firstIndex(of: 0x0A) {
                line.append(chunk[chunk.startIndex..<newline])
                break
            }
            line.append(chunk)
        }
        guard let first = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any],
              let payload = first["payload"] as? [String: Any] else { return nil }
        var helper = payload["parent_thread_id"] != nil && !(payload["parent_thread_id"] is NSNull)
        if let source = payload["source"] as? [String: Any], source["subagent"] != nil { helper = true }
        return SessionMeta(workspacePath: payload["cwd"] as? String, originator: payload["originator"] as? String, isHelper: helper)
    }
}
