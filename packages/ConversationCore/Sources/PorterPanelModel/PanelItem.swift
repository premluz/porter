import ConversationCore
import Foundation
import PorterStore

/// One tab that can be opened for an item. Several of these on one item means the user chooses.
public struct PanelRoute: Sendable, Equatable, Identifiable {
    public var id: UUID { destinationId }
    public let destinationId: UUID
    public let revision: Int
    public let tabId: Int?
    public let windowId: Int?
}

/// Why an item cannot be opened right now. Each case has a different recovery.
public enum Unavailable: Sendable, Equatable {
    /// Its source is connected but no tab shows it (a pin whose tab was closed).
    case closed
    /// Its source is not connected; nothing can be said about the tab.
    case sourceOffline
}

public enum Availability: Sendable, Equatable {
    case open([PanelRoute])
    case unavailable(Unavailable)
}

public struct ItemStatus: Sendable, Equatable {
    public let display: DisplayStatus
    public let freshness: Freshness
    /// Seconds since the last observation, only when there is one.
    public let ageSeconds: Int?
    /// What the most recent observation said, shown only as "last seen" when it is no longer fresh.
    public let lastKnown: DisplayStatus?

    public init(display: DisplayStatus, freshness: Freshness, ageSeconds: Int?, lastKnown: DisplayStatus? = nil) {
        self.display = display
        self.freshness = freshness
        self.ageSeconds = ageSeconds
        self.lastKnown = lastKnown
    }

    public static let unknown = ItemStatus(display: .unknown, freshness: .unknown, ageSeconds: nil)
}

public struct PanelItem: Sendable, Equatable, Identifiable {
    public var id: String { key.storageKey }
    public let key: ConversationKey
    public let title: String
    public let provider: String
    public let profileAlias: String?
    public let canonicalUrl: String?
    public let pinned: Bool
    public let hidden: Bool
    public let availability: Availability
    public let status: ItemStatus
    /// Another item has the same title, so the profile must be shown, not implied.
    public let sharesTitle: Bool

    public var routes: [PanelRoute] {
        if case .open(let routes) = availability { return routes }
        return []
    }

    /// The desktop-app way to reach this chat, when its provider documents one.
    public var desktopLink: DesktopLink? {
        provider == DesktopLinks.claudeProvider
            ? DesktopLinks.claudeChat(providerConversationId: key.providerConversationId) : nil
    }

    public var isAmbiguous: Bool { routes.count > 1 }

    public var isOpenable: Bool { !routes.isEmpty }
}
