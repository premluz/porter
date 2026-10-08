import Foundation

/// A conversation as the user remembers it: stable across browser restarts, unlike a tab ID.
/// While account identity is unverified it is scoped to the connector, so the same chat reached
/// from two profiles is two keys and a pin never silently moves to another profile.
public struct ConversationKey: Hashable, Sendable {
    public static let separator: Character = "/"
    private static let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-")

    public let provider: String
    public let connectorId: String
    public let providerConversationId: String

    public init(provider: String, connectorId: String, providerConversationId: String) throws(StoreError) {
        for part in [provider, connectorId, providerConversationId] {
            guard !part.isEmpty, part.count <= 128, part.unicodeScalars.allSatisfy(Self.allowed.contains) else {
                throw .invalidKey(part)
            }
        }
        self.provider = provider
        self.connectorId = connectorId
        self.providerConversationId = providerConversationId
    }

    public var storageKey: String {
        [provider, connectorId, providerConversationId].joined(separator: String(Self.separator))
    }

    public init(storageKey: String) throws(StoreError) {
        let parts = storageKey.split(separator: Self.separator, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else { throw .invalidKey(storageKey) }
        try self.init(provider: parts[0], connectorId: parts[1], providerConversationId: parts[2])
    }
}
