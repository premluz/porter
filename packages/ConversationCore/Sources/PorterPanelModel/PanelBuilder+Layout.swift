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

    /// Stable default: profile, then title, then first tab. Frozen positions win while interacting.
    private static func order(_ items: [PanelItem], frozen: [String]?) -> [PanelItem] {
        let natural = items.sorted {
            ($0.profileAlias ?? "", $0.title, $0.routes.first?.tabId ?? 0)
                < ($1.profileAlias ?? "", $1.title, $1.routes.first?.tabId ?? 0)
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
