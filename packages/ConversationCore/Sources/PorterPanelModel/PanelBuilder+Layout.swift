import ConversationCore
import Foundation

extension PanelBuilder {
    static func snapshot(
        _ visible: [PanelItem], allItems: [PanelItem], inputs: PanelInputs, unreadable: [String]
    ) -> PanelSnapshot {
        let shown = visible.filter { inputs.showHidden || !$0.hidden }
        let pinned = shown.filter(\.pinned).sorted { pinOrder($0, inputs) < pinOrder($1, inputs) }
        let open = order(shown.filter { !$0.pinned && $0.isOpenable }, frozen: inputs.frozenOrder)
        let hidden = visible.filter(\.hidden)
        let (needing, pinnedRest, openRest) = splitNeedsYou(pinned: pinned, open: open)
        return PanelSnapshot(
            needsYou: needing, pinned: pinnedRest, open: openRest, hidden: hidden,
            emptyState: emptyState(shown: shown, allItems: allItems, inputs: inputs), unreadable: unreadable
        )
    }

    /// A chat waits on the person only on a fresh signal; a stale one is never promoted. Oldest wait first would bury the
    /// newest question, so the most recent signal leads.
    private static func splitNeedsYou(pinned: [PanelItem], open: [PanelItem]) -> ([PanelItem], [PanelItem], [PanelItem]) {
        func waiting(_ item: PanelItem) -> Bool { item.status.freshness == .fresh && item.status.display == .needsUser && item.isOpenable }
        let needing = (pinned + open).filter(waiting).sorted { ($0.lastActiveAt ?? .distantPast) > ($1.lastActiveAt ?? .distantPast) }
        return (needing, pinned.filter { !waiting($0) }, open.filter { !waiting($0) })
    }

    private static func pinOrder(_ item: PanelItem, _ inputs: PanelInputs) -> Int {
        inputs.records.first { $0.key == item.key }?.pinOrder ?? Int.max
    }

    /// Most recently used first. Items with no reported time follow, then ties and unknowns fall back to a
    /// stable order (profile, title, first tab) so the list never shuffles by chance.
    /// Frozen positions win while the user is interacting, so nothing moves under the pointer.
    private static func order(_ items: [PanelItem], frozen: [String]?) -> [PanelItem] {
        let natural = items.sorted { lhs, rhs in
            switch (lhs.lastActiveAt, rhs.lastActiveAt) {
            case let (left?, right?) where left != right: return left > right
            case (_?, nil): return true
            case (nil, _?): return false
            default:
                if let left = lhs.listRank, let right = rhs.listRank, left != right { return left < right }
                return (lhs.profileAlias ?? "", lhs.title, lhs.routes.first?.tabId ?? 0, lhs.id)
                    < (rhs.profileAlias ?? "", rhs.title, rhs.routes.first?.tabId ?? 0, rhs.id)
            }
        }
        guard let frozen else { return natural }
        let position = Dictionary(uniqueKeysWithValues: frozen.enumerated().map { ($1, $0) })
        let known = natural.filter { position[$0.id] != nil }.sorted { position[$0.id]! < position[$1.id]! }
        return known + natural.filter { position[$0.id] == nil }
    }

    private static func emptyState(shown: [PanelItem], allItems: [PanelItem], inputs: PanelInputs) -> EmptyState? {
        guard shown.isEmpty else { return nil }
        if !inputs.query.trimmingCharacters(in: .whitespaces).isEmpty, !allItems.isEmpty {
            return .noMatches(query: inputs.query)
        }
        return inputs.connectors.isEmpty ? .noSources : .noConversations
    }
}
