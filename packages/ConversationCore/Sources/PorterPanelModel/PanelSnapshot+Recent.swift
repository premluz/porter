import Foundation

extension PanelSnapshot {
    /// How many open conversations the pane lists before folding the rest into an expandable group.
    public static let recentLimit = 6

    /// The most recently used open conversations, and the remainder. `open` is already newest first,
    /// and may be frozen while the pane is open, so the split follows what is on screen.
    public func recentSplit(limit: Int = PanelSnapshot.recentLimit) -> (recent: [PanelItem], older: [PanelItem]) {
        let cut = max(limit, 0)
        return (Array(open.prefix(cut)), Array(open.dropFirst(cut)))
    }

    /// What arrow keys and selection can reach: the folded group only counts while it is shown.
    public func navigable(showingOlder: Bool, limit: Int = PanelSnapshot.recentLimit) -> [PanelItem] {
        let split = recentSplit(limit: limit)
        return pinned + split.recent + (showingOlder ? split.older : [])
    }
}
