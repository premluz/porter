import Foundation

/// What the user chose to keep about a conversation. Only pinned or hidden conversations are
/// stored; an ordinary open chat is never written to disk. The title and link are the last
/// seen display metadata, kept so a pin still makes sense when its tab is closed.
public struct PreferenceRecord: Sendable, Equatable {
    public let key: ConversationKey
    public let title: String
    public let canonicalUrl: String?
    public let profileAlias: String?
    public let pinned: Bool
    public let pinOrder: Int
    public let hidden: Bool
    public let revision: Int
    public let modifiedAt: Date
    public let modifiedByDevice: UUID

    public init(
        key: ConversationKey, title: String, canonicalUrl: String?, profileAlias: String?, pinned: Bool,
        pinOrder: Int, hidden: Bool, revision: Int, modifiedAt: Date, modifiedByDevice: UUID
    ) {
        self.key = key
        self.title = title
        self.canonicalUrl = canonicalUrl
        self.profileAlias = profileAlias
        self.pinned = pinned
        self.pinOrder = pinOrder
        self.hidden = hidden
        self.revision = revision
        self.modifiedAt = modifiedAt
        self.modifiedByDevice = modifiedByDevice
    }
}

/// Display metadata supplied when the user pins or hides an item.
public struct ConversationSnapshot: Sendable, Equatable {
    public let key: ConversationKey
    public let title: String
    public let canonicalUrl: String?
    public let profileAlias: String?

    public init(key: ConversationKey, title: String, canonicalUrl: String?, profileAlias: String?) {
        self.key = key
        self.title = title
        self.canonicalUrl = canonicalUrl
        self.profileAlias = profileAlias
    }
}
