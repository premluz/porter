import Foundation

/// What pressing Return (or clicking) should do for the selected item.
public enum SelectionAction: Sendable, Equatable {
    case activate(PanelItem, PanelRoute)
    /// Several tabs show this chat; the user picks one. Porter never guesses.
    case chooseRoute(PanelItem)
    /// Not open anywhere: offer recovery rather than a dead click.
    case showRecovery(PanelItem)
    case nothing
}

/// Keyboard selection over the flat list. Pure, so the whole keyboard flow is testable.
public struct PanelSelection: Sendable, Equatable {
    public private(set) var selectedId: String?

    public init(selectedId: String? = nil) {
        self.selectedId = selectedId
    }

    public mutating func moveDown(in items: [PanelItem]) {
        move(by: 1, in: items)
    }

    public mutating func moveUp(in items: [PanelItem]) {
        move(by: -1, in: items)
    }

    /// Typing replaces the list, so selection returns to the first match.
    public mutating func reset(to items: [PanelItem]) {
        selectedId = items.first?.id
    }

    /// Keeps the selected item where it is when the list updates; if it is gone, selects the nearest.
    public mutating func reconcile(with items: [PanelItem], previous: [PanelItem]) {
        guard let current = selectedId, !items.contains(where: { $0.id == current }) else { return }
        let oldIndex = previous.firstIndex { $0.id == current } ?? 0
        selectedId = items.isEmpty ? nil : items[min(oldIndex, items.count - 1)].id
    }

    public mutating func select(_ id: String?) {
        selectedId = id
    }

    public func action(in items: [PanelItem]) -> SelectionAction {
        guard let item = items.first(where: { $0.id == selectedId }) else { return .nothing }
        switch item.routes.count {
        case 0: return .showRecovery(item)
        case 1: return .activate(item, item.routes[0])
        default: return .chooseRoute(item)
        }
    }

    private mutating func move(by step: Int, in items: [PanelItem]) {
        guard !items.isEmpty else { selectedId = nil; return }
        guard let current = items.firstIndex(where: { $0.id == selectedId }) else {
            selectedId = (step > 0 ? items.first : items.last)?.id
            return
        }
        selectedId = items[min(max(current + step, 0), items.count - 1)].id
    }
}
