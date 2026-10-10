import Foundation

public enum EmptyState: Sendable, Equatable {
    /// No browser profile has ever connected.
    case noSources
    /// A source is connected but nothing supported is open and nothing is pinned.
    case noConversations
    case noMatches(query: String)
}

public struct PanelSnapshot: Sendable, Equatable {
    /// Chats whose agent is waiting on the person (a fresh "needs you"), newest first. They are listed here and not
    /// again among the pinned or open ones, so the first thing in the pane is what is waiting.
    public let needsYou: [PanelItem]
    public let pinned: [PanelItem]
    public let open: [PanelItem]
    public let hidden: [PanelItem]
    public let emptyState: EmptyState?
    /// Rows that could not be turned into items; shown in diagnostics instead of being dropped silently.
    public let unreadable: [String]

    /// Display order for navigation: what needs you, then pinned, then open.
    public var navigable: [PanelItem] { needsYou + pinned + open }
}
