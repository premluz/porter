import Foundation
import Testing
@testable import ConversationCore

/// The cases mirror extensions/chrome/tests/claude.test.ts, so the Swift and TypeScript rules cannot drift apart.
@Suite("Provider recognizers apply the same identity rules as the browser extension")
struct ProviderRecognizerTests {
    @Test("a chat is identified from the URL alone, dropping query and fragment")
    func identifies() {
        let match = ProviderRecognizers.claude.match(url: "https://claude.ai/chat/5c0e1a52-aaaa-bbbb-cccc-0123456789ab?x=1#frag")
        #expect(match == ConversationMatch(
            providerConversationId: "5c0e1a52-aaaa-bbbb-cccc-0123456789ab",
            canonicalUrl: "https://claude.ai/chat/5c0e1a52-aaaa-bbbb-cccc-0123456789ab"
        ))
        #expect(ProviderRecognizers.chatgpt.match(url: "https://chatgpt.com/c/abc-123")?.canonicalUrl == "https://chatgpt.com/c/abc-123")
    }

    @Test("look-alike and non-chat addresses are rejected")
    func rejects() {
        let rejected: [String?] = [
            nil, "not a url", "http://claude.ai/chat/abc", "https://claude.ai/", "https://claude.ai/new",
            "https://claude.ai/chat/", "https://claude.ai/chat/abc/extra", "https://claude.ai/project/abc",
            "https://claude.ai:8443/chat/abc", "https://www.claude.ai/chat/abc", "https://claude.ai.evil.example/chat/abc",
            "https://claude.ai@evil.example/chat/abc", "https://evil.example/chat/abc?u=https://claude.ai/chat/abc",
            "https://claude.ai/chat/abc%2F..%2Fdef", "javascript:alert(1)",
            "https://chatgpt.com/chat/abc", "https://claude.ai/c/abc",
        ]
        for url in rejected {
            #expect(ProviderRecognizers.claude.match(url: url) == nil, "\(url ?? "nil")")
        }
        #expect(ProviderRecognizers.claude.match(url: "https://claude.ai/c/abc") == nil)
        #expect(ProviderRecognizers.chatgpt.match(url: "https://claude.ai/chat/abc") == nil)
    }

    @Test("titles lose the provider suffix, and empty or bare names become untitled")
    func titles() {
        let claude = ProviderRecognizers.claude
        #expect(claude.cleanTitle("Release plan - Claude") == "Release plan")
        #expect(claude.cleanTitle("Release plan | Claude") == "Release plan")
        #expect(claude.cleanTitle("Claude") == "Untitled conversation")
        #expect(claude.cleanTitle(nil) == "Untitled conversation")
        #expect(claude.cleanTitle(String(repeating: "x", count: 600)).count == 512)
        #expect(ProviderRecognizers.chatgpt.cleanTitle("Trip ideas - ChatGPT") == "Trip ideas")
    }

    @Test("the registry picks the one provider that matches, and exposes adapter versions")
    func registry() {
        #expect(ProviderRecognizers.recognize(url: "https://chatgpt.com/c/x1")?.recognizer.provider == "chatgpt")
        #expect(ProviderRecognizers.recognize(url: "https://example.com/c/x1") == nil)
        #expect(ProviderRecognizers.adapterVersions == ["claude": "0.1.0", "chatgpt": "0.1.0"])
        #expect(ProviderRecognizers.recognizer(for: "claude")?.verified == true)
    }
}
