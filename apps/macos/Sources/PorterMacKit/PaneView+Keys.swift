import PorterPanelModel
import SwiftUI

extension PaneView {
    /// Arrows move, Escape unwinds then closes, ⌘P pins, ⌘⌫ hides. Everything else types normally.
    func handle(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .downArrow:
            model.moveSelection(down: true)
            return .handled
        case .upArrow:
            model.moveSelection(down: false)
            return .handled
        case .escape:
            if !model.escape() { close() }
            return .handled
        case .delete where press.modifiers.contains(.command):
            return act { await model.toggleHidden($0) }
        case let key where press.modifiers.contains(.command) && key.character == "p":
            return act { await model.togglePin($0) }
        case let key where press.modifiers.contains(.command) && key.character == "o":
            model.openSelectedInDesktopApp()
            return .handled
        default:
            return .ignored
        }
    }

    private func act(_ action: @escaping (PanelItem) async -> Void) -> KeyPress.Result {
        guard let item = model.selectedItem else { return .ignored }
        Task { await action(item) }
        return .handled
    }
}
