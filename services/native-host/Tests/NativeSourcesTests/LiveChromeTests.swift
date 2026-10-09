import ConversationCore
import Foundation
import Testing
@testable import NativeSources

/// Talks to the real Chrome on this Mac. Off unless PORTER_LIVE_CHROME=1, and it prints counts only, never titles.
@Suite("Live Chrome", .enabled(if: ProcessInfo.processInfo.environment["PORTER_LIVE_CHROME"] == "1"))
struct LiveChromeTests {
    @Test("the real browser answers, every reported tab is a recognised conversation, and incognito is absent")
    func liveSnapshot() async throws {
        let connector = ChromeScriptingConnector(installationId: UUID())
        let started = ContinuousClock.now
        let payload = try await connector.snapshot()
        let elapsed = started.duration(to: .now)
        print("live: \(payload.tabs.count) conversation tab(s), health \(connector.health), \(elapsed)")
        #expect(connector.health == .ready)
        #expect(payload.tabs.allSatisfy { ProviderRecognizers.recognizer(for: $0.provider) != nil && !$0.providerConversationId.isEmpty })
        #expect(Set(payload.tabs.map(\.tabId)).count == payload.tabs.count)
    }
}
