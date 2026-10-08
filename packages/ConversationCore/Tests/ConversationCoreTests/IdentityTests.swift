import Foundation
import Testing
@testable import ConversationCore

@Suite("Destination identity")
struct IdentityTests {
    private func observed(
        account: AccountScope?, conversation: String?, connector: String = "chrome-personal",
        epoch: String = "identity-1", provider: String = "claude"
    ) -> IdentityKey.Observed {
        IdentityKey.Observed(
            provider: provider, account: account, workspaceId: nil, providerConversationId: conversation,
            connectorId: connector, identityEpoch: epoch, temporaryId: UUID()
        )
    }

    @Test("two same-title conversations in different profiles stay distinct")
    func sameTitleStaysDistinct() throws {
        let personal = try ContractFixtures.decode(Conversation.self, "conversation", "personal-release-plan")
        let work = try ContractFixtures.decode(Conversation.self, "conversation", "work-same-title")
        #expect(personal.title == work.title)
        let a = IdentityKey(observed(account: nil, conversation: personal.providerConversationId))
        let b = IdentityKey(observed(account: nil, conversation: work.providerConversationId, connector: "chrome-work"))
        #expect(a != b)
    }

    @Test("unknown or user-labelled accounts never produce a verified key")
    func unverifiedAccountsStayConnectorScoped() throws {
        for name in ["unknown", "user-label"] {
            let scope = try ContractFixtures.decode(AccountScope.self, "account-scope", name)
            let key = IdentityKey(observed(account: scope, conversation: "fixture-chat-a"))
            #expect(!key.isVerified, "\(name) must not verify")
        }
    }

    @Test("same conversation ID in two profiles with unknown account is not merged")
    func unknownAccountNotMergedAcrossProfiles() {
        let a = IdentityKey(observed(account: nil, conversation: "fixture-chat-a", connector: "chrome-personal"))
        let b = IdentityKey(observed(account: nil, conversation: "fixture-chat-a", connector: "chrome-work"))
        #expect(a != b)
    }

    @Test("a verified account merges the same conversation across connectors")
    func verifiedAccountMerges() throws {
        let scope = try ContractFixtures.decode(AccountScope.self, "account-scope", "provider-reported")
        let a = IdentityKey(observed(account: scope, conversation: "fixture-chat-a", connector: "chrome-personal"))
        let b = IdentityKey(observed(account: scope, conversation: "fixture-chat-a", connector: "chrome-work"))
        #expect(a.isVerified)
        #expect(a == b)
    }

    @Test("an account from another provider does not verify this provider's conversation")
    func crossProviderAccountIgnored() throws {
        let scope = try ContractFixtures.decode(AccountScope.self, "account-scope", "provider-reported")
        let key = IdentityKey(observed(account: scope, conversation: "fixture-chat-a", provider: "chatgpt"))
        #expect(!key.isVerified)
    }

    @Test("an identity-epoch change yields a different key for the same route")
    func epochChangeSeparatesKeys() {
        let before = IdentityKey(observed(account: nil, conversation: "fixture-chat-a", epoch: "identity-1"))
        let after = IdentityKey(observed(account: nil, conversation: "fixture-chat-a", epoch: "identity-2"))
        #expect(before != after)
    }

    @Test("unsaved chats get unique temporary keys")
    func unsavedChatsDoNotCollide() {
        let a = IdentityKey(observed(account: nil, conversation: nil))
        let b = IdentityKey(observed(account: nil, conversation: nil))
        #expect(a != b)
    }
}
