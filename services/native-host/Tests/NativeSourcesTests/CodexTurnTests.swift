import ConversationCore
import Foundation
import Testing
@testable import NativeSources

/// Session files made of the records Codex writes at turn boundaries, in the shape the real ones have (checked on this
/// Mac by record type only): `{"timestamp":…,"ordinal":n,"type":"event_msg","payload":{"type":"task_started",…}}`.
private struct RolloutFile {
    let path: String

    init() {
        path = NSTemporaryDirectory() + "porter-rollout-\(UUID().uuidString).jsonl"
        FileManager.default.createFile(atPath: path, contents: nil)
    }

    /// A thread's existing session file, to add turn records to.
    init(existing path: String) { self.path = path }

    func remove() { try? FileManager.default.removeItem(atPath: path) }

    func append(_ line: String) throws {
        let handle = try #require(FileHandle(forWritingAtPath: path))
        handle.seekToEndOfFile()
        handle.write(Data((line + "\n").utf8))
        try handle.close()
    }

    func event(_ type: String) throws {
        try append(#"{"timestamp":"2026-10-10T11:18:03.029Z","ordinal":1,"type":"event_msg","payload":{"type":"\#(type)","turn_id":"t"}}"#)
    }

    /// A message that talks about the markers: JSON puts a backslash before every quote inside a string.
    func chatterAboutMarkers() throws {
        let text = #""type":"event_msg","payload":{"type":"task_started""#
        let record = try JSONSerialization.data(withJSONObject: ["type": "response_item", "payload": ["type": "message", "text": text]])
        try append(String(decoding: record, as: UTF8.self))
    }

    func touched(_ moment: Date) throws {
        try FileManager.default.setAttributes([.modificationDate: moment], ofItemAtPath: path)
    }
}

private let now = Date(timeIntervalSince1970: 1_791_558_000)

@Suite("Whether a Codex thread is in the middle of a turn")
struct CodexTurnStateTests {
    private func open(_ file: RolloutFile, ago: TimeInterval = 5) throws -> Bool {
        try file.touched(now.addingTimeInterval(-ago))
        return CodexTurnState.isOpen(atPath: file.path, now: now)
    }

    @Test("a turn started and not ended is open, one that completed or was interrupted is not, and the next turn opens again")
    func boundaries() throws {
        let file = RolloutFile()
        defer { file.remove() }
        try file.event("task_started")
        #expect(try open(file))
        try file.event("task_complete")
        #expect(try !open(file))
        try file.event("task_started")
        #expect(try open(file))
        try file.event("turn_aborted")
        #expect(try !open(file))
    }

    @Test("records that are not boundaries do not decide it, and a file with no turn at all is not working")
    func otherRecords() throws {
        let file = RolloutFile()
        defer { file.remove() }
        try file.event("thread_settings_applied")
        #expect(try !open(file))
        try file.event("task_started")
        try file.event("token_count")
        try file.event("item_completed")
        #expect(try open(file))
    }

    @Test("a turn whose file has gone quiet is not claimed, which covers a killed Codex that left it open")
    func silence() throws {
        let file = RolloutFile()
        defer { file.remove() }
        try file.event("task_started")
        #expect(try open(file, ago: CodexTurnState.silence - 5))
        #expect(try !open(file, ago: CodexTurnState.silence + 5))
    }

    @Test("a message that quotes the markers is not a marker")
    func quoting() throws {
        let file = RolloutFile()
        defer { file.remove() }
        try file.event("task_started")
        try file.event("task_complete")
        try file.chatterAboutMarkers()
        #expect(try !open(file))
    }

    @Test("a missing file is not working, and a turn buried deeper than the search reaches is not claimed")
    func limits() throws {
        #expect(!CodexTurnState.isOpen(atPath: NSTemporaryDirectory() + "porter-nowhere.jsonl", now: now))
        let file = RolloutFile()
        defer { file.remove() }
        try file.event("task_started")
        try file.append(String(repeating: "x", count: CodexTurnState.tailLimit + 1_000))
        #expect(try !open(file))
    }

    @Test("a huge record between the markers is searched in a few milliseconds")
    func fast() throws {
        let file = RolloutFile()
        defer { file.remove() }
        try file.event("task_complete")
        try file.event("task_started")
        try file.append(String(repeating: "y", count: 12 * 1024 * 1024))
        try file.touched(now.addingTimeInterval(-5))
        let clock = ContinuousClock()
        var found = false
        let elapsed = clock.measure { found = CodexTurnState.isOpen(atPath: file.path, now: now) }
        #expect(found && elapsed < .milliseconds(250))
    }
}

@Suite("The Codex connector reporting a turn in progress")
struct CodexWorkingReportTests {
    private let a = "0199c2f4-7a1e-7d52-9b0e-3c5d8a6f1b24"
    private let b = "0199c2f4-7a1e-7d52-9b0e-3c5d8a6f1b25"

    private func connector(_ home: FakeCodexHome) -> CodexThreadsConnector {
        CodexThreadsConnector(installationId: UUID(), index: CodexThreadIndex(home: home.path), pollInterval: .milliseconds(20), now: { now })
    }

    @Test("only the thread whose turn is open is reported working, the rest are reported with no claim")
    func snapshot() async throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        try home.thread(a, title: "Busy", updated: "2026-10-09T14:00:00Z")
        try home.thread(b, title: "Finished", updated: "2026-10-09T13:00:00Z")
        let busy = RolloutFile(existing: home.session(a)), finished = RolloutFile(existing: home.session(b))
        try busy.event("task_started")
        try finished.event("task_started")
        try finished.event("task_complete")
        try busy.touched(now.addingTimeInterval(-5))
        try finished.touched(now.addingTimeInterval(-5))
        let entries = try #require(try await connector(home).snapshot().appEntries)
        #expect(entries.first { $0.providerConversationId == a }?.working == true)
        #expect(entries.first { $0.providerConversationId == b }?.working == nil)
    }

    @Test("a turn starting is noticed by the poll, and so is it ending")
    func noticesTurns() async throws {
        let home = try FakeCodexHome()
        defer { home.remove() }
        try home.thread(a, title: "Busy", updated: "2026-10-09T14:00:00Z")
        let session = RolloutFile(existing: home.session(a))
        try session.touched(now.addingTimeInterval(-5))
        var iterator = connector(home).changes().makeAsyncIterator()
        try await Task.sleep(for: .milliseconds(60))
        try session.event("task_started")
        try session.touched(now.addingTimeInterval(-5))
        #expect(await iterator.next() != nil)
        try session.event("task_complete")
        try session.touched(now.addingTimeInterval(-5))
        #expect(await iterator.next() != nil)
    }
}
