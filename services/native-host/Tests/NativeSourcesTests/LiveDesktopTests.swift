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
