import Foundation

public enum EmptyState: Sendable, Equatable {
    /// No browser profile has ever connected.
    case noSources
    /// A source is connected but nothing supported is open and nothing is pinned.
    case noConversations
    case noMatches(query: String)
}

public struct PanelSnapshot: Sendable, Equatable {
    public let pinned: [PanelItem]
    public let open: [PanelItem]
    public let hidden: [PanelItem]
    public let emptyState: EmptyState?
    /// Rows that could not be turned into items; shown in diagnostics instead of being dropped silently.
    public let unreadable: [String]

    /// Display order for navigation: pinned first, then open.
    public var navigable: [PanelItem] { pinned + open }
}
