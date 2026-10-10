import AppKit

/// What the pointer is over, and what that does: hover looks, the pointing hand, labels, and peeking out of the dock.
extension PanelController {
    /// What is under the pointer: the docked tab, in the capsule a dot or the open button, in the open pane a row.
    func clickable(at point: CGPoint) -> String? {
        switch machine.phase {
        case .collapsed:
            if layout.restIsTab {
                return presentation.rest.rect.insetBy(dx: -6, dy: -6).contains(point) ? PanelPresentation.openButtonId : nil
            }
            return CapsuleHover.item(at: point, frames: presentation.dotFrames)
        case .expanded:
            // Rows scrolled under the search field or the footer are still laid out, so only the visible list counts.
            guard presentation.listFrame.contains(point) else { return nil }
            return CapsuleHover.item(at: point, frames: presentation.rowFrames, horizontalReach: 0, verticalReach: 0)
        default:
            return nil
        }
    }

    /// A tab, a dot, the open button and a row take a click, so they show the pointing hand. Collapsed, everything else is
    /// the arrow; open, the arrow is restored once on leaving a row and otherwise the views underneath choose.
    func cursor(at point: CGPoint) -> NSCursor? {
        if clickable(at: point) != nil {
            showingHand = true
            return .pointingHand
        }
        defer { showingHand = false }
        return machine.phase == .collapsed || showingHand ? .arrow : nil
    }

    /// Collapsed, the dot under the pointer is lit and its label shown at once; the label glides to the next dot and
    /// leaves only when the pointer leaves the dots altogether. A docked tab grows into the capsule under the pointer.
    func pointerMoved(to point: CGPoint?) {
        trackPeek(point)
        let hit = point.flatMap(clickable(at:))
        let collapsed = machine.phase == .collapsed
        let dot = collapsed ? hit : nil
        let row = collapsed ? nil : hit
        if presentation.hoveredDot != dot { presentation.hoveredDot = dot }
        if presentation.hoveredRow != row { presentation.hoveredRow = row }
        guard collapsed, drag == nil, let hit, let item = model.items.first(where: { $0.id == hit }), let frame = presentation.dotFrames[hit] else {
            tooltips.hide()
            return
        }
        let visible = visibleFrame
        tooltips.show(
            item, anchor: CapsuleHover.screenRect(of: frame, inWindow: panel.frame), window: panel.frame,
            edge: layout.paneEdge(in: visible), visible: visible
        )
    }

    private func trackPeek(_ point: CGPoint?) {
        guard machine.phase == .collapsed, settings.mode == .docked, drag == nil else { return }
        let inside = point.map { presentation.rest.rect.insetBy(dx: -6, dy: -6).contains($0) } ?? false
        if inside {
            peekEnd?.cancel()
            beginPeek()
        } else if peeking {
            scheduleEndPeek()
        }
    }
}
