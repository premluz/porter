import Foundation
import Testing
@testable import ConversationCore

@Suite("Destination registry and locator policy")
struct RegistryTests {
    @Test("older revisions never overwrite newer ones")
    func revisionOrdering() {
        var registry = DestinationRegistry()
        let id = UUID()
        #expect(registry.upsert(Sample.tab(id: id, revision: 2)) == .inserted)
        #expect(registry.upsert(Sample.tab(id: id, revision: 1)) == .ignoredOlderRevision)
        #expect(registry.upsert(Sample.tab(id: id, revision: 3)) == .updated)
    }

    @Test("resolution detects gone and changed targets before opening")
    func resolution() {
        var registry = DestinationRegistry()
        let id = UUID()
        _ = registry.upsert(Sample.tab(id: id, revision: 2))
        #expect(registry.resolve(id, expectedRevision: 1) == .changed(currentRevision: 2))
        #expect(registry.resolve(UUID(), expectedRevision: 1).failureOutcome == .targetGone)
        registry.remove(id)
        #expect(registry.resolve(id, expectedRevision: 2) == .gone)
    }

    @Test("an identity-epoch change retires old routes and blocks late old-epoch upserts")
    func accountChangeRetires() {
        var registry = DestinationRegistry()
        let id = UUID()
        registry.beginIdentityEpoch("identity-1", connectorId: "chrome-personal")
        _ = registry.upsert(Sample.tab(id: id, identityEpoch: "identity-1"))
        let retired = registry.beginIdentityEpoch("identity-2", connectorId: "chrome-personal")
        #expect(retired == [id])
        #expect(registry.resolve(id, expectedRevision: 1).failureOutcome == .accountChanged)
        let late = registry.upsert(Sample.tab(identityEpoch: "identity-1"))
        #expect(late == .rejected(.staleIdentityEpoch))
    }

    @Test("several routes to one conversation are all returned for the user to choose")
    func ambiguityIsSurfaced() {
        var registry = DestinationRegistry()
        let conversation = UUID()
        _ = registry.upsert(Sample.tab(conversationId: conversation, connectorId: "chrome-personal"))
        _ = registry.upsert(Sample.tab(conversationId: conversation, connectorId: "chrome-work"))
        #expect(registry.destinations(forConversation: conversation).count == 2)
    }

    @Test("plain-http browser URLs are rejected")
    func httpRejected() {
        var registry = DestinationRegistry()
        let outcome = registry.upsert(Sample.tab(url: "http://claude.ai/chat/x"))
        #expect(outcome == .rejected(.locator(.insecureWebURL("http://claude.ai/chat/x"))))
    }

    @Test("deep links are refused unless their scheme is explicitly allowed")
    func deepLinkSchemes() {
        let link = Locator.desktopLink(DesktopLinkLocator(
            bundleId: "com.anthropic.claudefordesktop", deepLink: "claude://fixture/link", accountScopeId: nil
        ))
        #expect(throws: LocatorRejection.disallowedScheme("claude")) { try LocatorPolicy().validate(link) }
        #expect(throws: Never.self) { try LocatorPolicy(allowedDeepLinkSchemes: ["claude"]).validate(link) }
    }

    @Test("dangerous schemes cannot be allowlisted")
    func dangerousSchemesNeverAllowed() {
        let policy = LocatorPolicy(allowedDeepLinkSchemes: ["file", "javascript"])
        for url in ["file:///etc/hosts", "javascript:alert(1)"] {
            let link = Locator.mobileLink(MobileLinkLocator(url: url, accountRequirement: nil))
            #expect(throws: LocatorRejection.self) { try policy.validate(link) }
        }
    }
}

@Suite("Claude desktop chat links")
struct DesktopLinkTests {
    @Test("a chat ID becomes exactly the documented link")
    func buildsDocumentedLink() {
        let link = DesktopLinks.claudeChat(providerConversationId: "32d0b096-f463-85b5-a77f-1b7fd27d93d8")
        #expect(link?.url == "claude://claude.ai/chat/32d0b096-f463-85b5-a77f-1b7fd27d93d8")
        #expect(link?.bundleId == "com.anthropic.claudefordesktop")
    }

    @Test("an ID that could carry extra link syntax is refused")
    func refusesUnsafeIds() {
        for id in ["", "a/b", "a?q=hi", "a#x", "a b", "a%2Fb", "chat:1", String(repeating: "a", count: 129)] {
            #expect(DesktopLinks.claudeChat(providerConversationId: id) == nil, "\(id)")
        }
    }

    @Test("only the exact documented shape is accepted, never a prompt prefill or another host")
    func acceptsOnlyExactShape() {
        #expect(DesktopLinks.isAllowedClaudeChatLink("claude://claude.ai/chat/abc-123"))
        let rejected = [
            "claude://claude.ai/new?q=hello", "claude://claude.ai/chat/abc?q=hi", "claude://claude.ai/chat/abc#x",
            "claude://claude.ai/chat/", "claude://claude.ai/chat/abc/def", "claude://claude.ai:443/chat/abc",
            "claude://user@claude.ai/chat/abc", "claude://evil.example/chat/abc", "claude://code/new?folder=/",
            "claude://cowork/new", "https://claude.ai/chat/abc", "claude://claude.ai/project/abc",
        ]
        for link in rejected { #expect(!DesktopLinks.isAllowedClaudeChatLink(link), "\(link)") }
    }

    @Test("the registry accepts that link as a desktop destination and still refuses other claude links")
    func policyAcceptsOnlyThatLink() {
        let policy = LocatorPolicy()
        func locator(_ bundle: String, _ link: String) -> Locator {
            .desktopLink(DesktopLinkLocator(bundleId: bundle, deepLink: link, accountScopeId: nil))
        }
        #expect(throws: Never.self) {
            try policy.validate(locator(DesktopLinks.claudeBundleId, "claude://claude.ai/chat/abc"))
        }
        #expect(throws: LocatorRejection.disallowedScheme("claude")) {
            try policy.validate(locator(DesktopLinks.claudeBundleId, "claude://claude.ai/new?q=hi"))
        }
        #expect(throws: LocatorRejection.disallowedScheme("claude")) {
            try policy.validate(locator("com.example.other", "claude://claude.ai/chat/abc"))
        }
    }
}
