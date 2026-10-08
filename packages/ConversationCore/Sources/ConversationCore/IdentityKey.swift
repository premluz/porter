import Foundation

/// The key two observed routes must share before they are treated as one conversation.
/// Titles and URLs are deliberately not inputs: matching text never authorizes a merge.
public enum IdentityKey: Hashable, Sendable {
    /// Provider + confirmed account + workspace + provider conversation ID.
    case verified(provider: String, accountId: String, workspaceId: String?, conversationId: String)
    /// Account unconfirmed or route unsaved: unique to one connector and identity epoch.
    case connectorScoped(connectorId: String, identityEpoch: String, localId: String)

    public struct Observed: Sendable {
        public let provider: String
        public let account: AccountScope?
        public let workspaceId: String?
        public let providerConversationId: String?
        public let connectorId: String
        public let identityEpoch: String
        /// Stable per observation context; used when no provider conversation ID exists yet.
        public let temporaryId: UUID

        public init(
            provider: String, account: AccountScope?, workspaceId: String?, providerConversationId: String?,
            connectorId: String, identityEpoch: String, temporaryId: UUID
        ) {
            self.provider = provider
            self.account = account
            self.workspaceId = workspaceId
            self.providerConversationId = providerConversationId
            self.connectorId = connectorId
            self.identityEpoch = identityEpoch
            self.temporaryId = temporaryId
        }
    }

    public init(_ observed: Observed) {
        let accountId = observed.account.flatMap { scope in
            scope.provider == observed.provider ? scope.verifiedAccountId : nil
        }
        if let accountId, let conversationId = observed.providerConversationId {
            self = .verified(
                provider: observed.provider, accountId: accountId,
                workspaceId: observed.workspaceId, conversationId: conversationId
            )
        } else {
            self = .connectorScoped(
                connectorId: observed.connectorId, identityEpoch: observed.identityEpoch,
                localId: observed.providerConversationId ?? observed.temporaryId.uuidString
            )
        }
    }

    public var isVerified: Bool {
        if case .verified = self { return true }
        return false
    }
}
