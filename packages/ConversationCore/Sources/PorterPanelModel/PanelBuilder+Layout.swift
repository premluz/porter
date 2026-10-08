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
        return PanelSnapshot(
            pinned: pinned, open: open, hidden: hidden,
            emptyState: emptyState(shown: shown, allItems: allItems, inputs: inputs), unreadable: unreadable
        )
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
