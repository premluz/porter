import Foundation
import Testing
@testable import NativeSources

/// Reads the real Claude and ChatGPT apps on this Mac. Off unless PORTER_LIVE_APPS=1, needs the Accessibility
/// permission for the process that runs the tests, and prints counts only, never titles.
@Suite("Live desktop apps", .enabled(if: ProcessInfo.processInfo.environment["PORTER_LIVE_APPS"] == "1"))
struct LiveDesktopTests {
    @Test("each running app answers with entries, or says plainly why it cannot")
    func liveSnapshot() async throws {
        let live = LiveAccessibility()
        try #require(live.isTrusted, "grant Accessibility to the process running the tests (or run the Porter app with it)")
        let source = DesktopAppConnector(installationId: UUID(), accessibility: live)
        let entries = try await source.snapshot().appEntries ?? []
        print("live: \(entries.count) entries; health \(source.health)")
        #expect(Set(entries.map(\.providerConversationId)).count == entries.count)
    }
}

/// Reads this Mac's real Codex thread list. Off unless PORTER_LIVE_CODEX=1; prints counts only, never titles.
@Suite("Live Codex threads", .enabled(if: ProcessInfo.processInfo.environment["PORTER_LIVE_CODEX"] == "1"))
struct LiveCodexTests {
    @Test("the real thread list reads, with helper threads left out and every entry having an id and a time")
    func liveThreads() async throws {
        let source = CodexThreadsConnector(installationId: UUID())
        try #require(source.isAvailable, "no ~/.codex/session_index.jsonl on this Mac")
        let started = ContinuousClock.now
        let entries = try await source.snapshot().appEntries ?? []
        let projects = Set(entries.compactMap { $0.workspacePath.map { ($0 as NSString).lastPathComponent } }).count
        print("live: \(entries.count) threads in \(projects) project(s), \(started.duration(to: .now))")
        #expect(Set(entries.map(\.providerConversationId)).count == entries.count)
        #expect(entries.allSatisfy { $0.lastActiveAt != nil && !$0.title.isEmpty })
    }
}
