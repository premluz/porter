import ConversationCore
import Foundation
import Synchronization
import Testing
@testable import NativeSources

/// A synthetic ~/.codex with the shape the real one has: an index, and one dated session file per thread whose first
/// line is a session_meta record. Titles and folders are placeholders.
private struct FakeCodexHome {
    let path: String

    init() throws {
        path = NSTemporaryDirectory() + "porter-codex-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: path + "/sessions/2026/10/09", withIntermediateDirectories: true)
    }

    func remove() { try? FileManager.default.removeItem(atPath: path) }

    func thread(
        _ id: String, title: String, updated: String, cwd: String? = "/Users/example/Atlas", originator: String = "codex_vscode",
        subagent: Bool = false, parent: String? = nil, writeSession: Bool = true
    ) throws {
        let line = #"{"id":"\#(id)","thread_name":"\#(title)","updated_at":"\#(updated)"}"# + "\n"
        let index = path + "/session_index.jsonl"
        if let handle = FileHandle(forWritingAtPath: index) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try handle.close()
        } else {
            try line.write(toFile: index, atomically: true, encoding: .utf8)
        }
        guard writeSession else { return }
        var payload: [String: Any] = ["id": id, "originator": originator, "base_instructions": String(repeating: "x", count: 200_000)]
        if let cwd { payload["cwd"] = cwd }
        payload["source"] = subagent ? ["subagent": ["other": "guardian"]] : "vscode"
        if let parent { payload["parent_thread_id"] = parent }
        let record = try JSONSerialization.data(withJSONObject: ["type": "session_meta", "payload": payload])
        var file = record
        file.append(Data("\n{\"type\":\"message\",\"payload\":{\"text\":\"must never be read\"}}\n".utf8))
        try file.write(to: URL(fileURLWithPath: path + "/sessions/2026/10/09/rollout-2026-10-09T10-00-00-\(id).jsonl"))
    }
}

private final class RecordingOpener: URLOpening {
    private let urls = Mutex<[URL]>([])
    var opened: [URL] { urls.withLock { $0 } }
    func open(_ url: URL) async -> Bool {
        urls.withLock { $0.append(url) }
        return true
    }
}

private let now = Date(timeIntervalSince1970: 1_791_558_000) // 2026-10-09T15:00:00Z
private let a = "0199c2f4-7a1e-7d52-9b0e-3c5d8a6f1b24"
private let b = "0199c2f4-7a1e-7d52-9b0e-3c5d8a6f1b25"
private let c = "0199c2f4-7a1e-7d52-9b0e-3c5d8a6f1b26"

@Suite("Reading Codex's own thread list")
struct CodexThreadIndexTests {
    @Test("recent threads come newest first with their folder and origin, and the session's later lines are never read")
    func reads() throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        try home.thread(a, title: "Older thread", updated: "2026-10-09T10:00:00.5Z")
        try home.thread(b, title: "Newest thread", updated: "2026-10-09T14:00:00Z", cwd: "/Users/example/Bastion", originator: "Codex Desktop")
        let threads = CodexThreadIndex(home: home.path).recentThreads(now: now)
        #expect(threads.map(\.title) == ["Newest thread", "Older thread"])
        #expect(threads[0].workspacePath == "/Users/example/Bastion" && !threads[0].startedInVSCode)
        #expect(threads[1].startedInVSCode)
    }

    @Test("helper threads (sub-agents and children) and threads older than the window are left out")
    func filters() throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        try home.thread(a, title: "Mine", updated: "2026-10-09T10:00:00Z")
        try home.thread(b, title: "Guardian", updated: "2026-10-09T11:00:00Z", subagent: true)
        try home.thread(c, title: "Child", updated: "2026-10-09T12:00:00Z", parent: a)
        try home.thread("0199c2f4-7a1e-7d52-9b0e-3c5d8a6f1b27", title: "Too old", updated: "2026-09-01T10:00:00Z")
        #expect(CodexThreadIndex(home: home.path).recentThreads(now: now).map(\.title) == ["Mine"])
    }

    @Test("a thread whose session file is missing is skipped, never listed with a guessed folder; a missing home is empty")
    func missingPieces() throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        try home.thread(a, title: "No file", updated: "2026-10-09T10:00:00Z", writeSession: false)
        #expect(CodexThreadIndex(home: home.path).recentThreads(now: now).isEmpty)
        let missing = CodexThreadIndex(home: home.path + "/nowhere")
        #expect(missing.recentThreads(now: now).isEmpty && !missing.isAvailable)
    }

    @Test("a thread that appears on several lines is listed once, with its latest title and time")
    func repeatedLines() throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        try home.thread(a, title: "First name", updated: "2026-10-09T10:00:00Z")
        try home.thread(a, title: "Renamed", updated: "2026-10-09T13:00:00Z", writeSession: false)
        try home.thread(a, title: "Stale echo", updated: "2026-10-09T09:00:00Z", writeSession: false)
        let threads = CodexThreadIndex(home: home.path).recentThreads(now: now)
        #expect(threads.map(\.title) == ["Renamed"])
        #expect(threads.first?.updatedAt == ISO8601DateFormatter().date(from: "2026-10-09T13:00:00Z"))
    }

    @Test("an untitled thread gets a plain name, and the fingerprint changes when the index does")
    func titlesAndFingerprint() throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        try home.thread(a, title: "  ", updated: "2026-10-09T10:00:00Z")
        let index = CodexThreadIndex(home: home.path)
        #expect(index.recentThreads(now: now).first?.title == "Untitled thread")
        let before = index.fingerprint()
        try home.thread(b, title: "Next", updated: "2026-10-09T11:00:00Z")
        #expect(index.fingerprint() != before)
    }
}

@Suite("The Codex threads connector")
struct CodexThreadsConnectorTests {
    private func connector(_ home: FakeCodexHome, opener: RecordingOpener = RecordingOpener()) -> CodexThreadsConnector {
        CodexThreadsConnector(installationId: UUID(), index: CodexThreadIndex(home: home.path), opener: opener, pollInterval: .milliseconds(20), now: { now })
    }

    private func request(_ id: String, title: String) throws -> ActivateRequestPayload {
        let json = #"{"requestId":"\#(UUID())","destinationId":"\#(UUID())","destinationRevision":1,"expectedProvider":"codex","expectedConversationId":"\#(id)","app":{"bundleId":"com.microsoft.VSCode","expectedTitle":"\#(title)","ordinal":0}}"#
        return try ContractCoding.decoder().decode(ActivateRequestPayload.self, from: Data(json.utf8))
    }

    @Test("threads become app entries keyed by the thread id, with project, host app, time and the list order")
    func snapshot() async throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        try home.thread(a, title: "In VS Code", updated: "2026-10-09T10:00:00Z")
        try home.thread(b, title: "In the app", updated: "2026-10-09T14:00:00Z", cwd: "/Users/example/Bastion", originator: "Codex Desktop")
        let entries = try #require(try await connector(home).snapshot().appEntries)
        #expect(entries.map(\.providerConversationId) == [b, a])
        #expect(entries.map(\.bundleId) == ["com.openai.codex", "com.microsoft.VSCode"])
        #expect(entries.map(\.position) == [0, 1] && entries.allSatisfy { $0.provider == "codex" && $0.ordinal == 0 && $0.lastActiveAt != nil })
        #expect(entries[1].workspacePath == "/Users/example/Atlas")
    }

    @Test("a VS Code thread opens through the extension's link, an app thread through the app's, after re-checking the title")
    func activation() async throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        try home.thread(a, title: "In VS Code", updated: "2026-10-09T10:00:00Z")
        try home.thread(b, title: "In the app", updated: "2026-10-09T14:00:00Z", originator: "Codex Desktop")
        let opener = RecordingOpener()
        let source = connector(home, opener: opener)
        #expect(await source.activate(try request(a, title: "In VS Code")) == .activated)
        #expect(await source.activate(try request(b, title: "In the app")) == .activated)
        #expect(opener.opened.map(\.absoluteString) == ["vscode://openai.chatgpt/local/\(a)", "codex://local/\(b)"])
        #expect(await source.activate(try request(a, title: "Renamed")) == .targetChanged)
        #expect(await source.activate(try request(c, title: "Gone")) == .targetGone)
        #expect(opener.opened.count == 2)
    }

    @Test("a request for another provider or without an app target is not handled")
    func unsupported() async throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        let json = #"{"requestId":"\#(UUID())","destinationId":"\#(UUID())","destinationRevision":1,"expectedProvider":"claude","expectedConversationId":"x","tabId":1,"windowId":1}"#
        let other = try ContractCoding.decoder().decode(ActivateRequestPayload.self, from: Data(json.utf8))
        #expect(await connector(home).activate(other) == .unsupported)
    }

    @Test("an update to the index is noticed by the poll")
    func noticesChanges() async throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        try home.thread(a, title: "First", updated: "2026-10-09T10:00:00Z")
        let source = connector(home)
        var iterator = source.changes().makeAsyncIterator()
        try await Task.sleep(for: .milliseconds(60))
        try home.thread(b, title: "Second", updated: "2026-10-09T11:00:00Z")
        let changed: Void? = await iterator.next()
        #expect(changed != nil)
    }
}
