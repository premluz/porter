import AppKit
import SwiftUI

/// The state of a drag that started on the capsule: how the capsule's centre sits relative to the pointer.
struct DragState {
    var offset: CGPoint
    var moved = false
}

/// Moving between the resting states: peeking out of the docked tab, being dragged, snapping to an edge and coming away.
extension PanelController {
    // MARK: Moving the resting shape

    /// Changes where the panel rests, and when it is closed animates the shape from where it is now to where it will be.
    /// The window grows to cover both for the move and shrinks to the new shape when it settles.
    func transitionRest(_ change: () -> Void) {
        guard machine.phase == .collapsed else {
            change()
            return
        }
        let current = presentation.restShape(at: Date())
        let from = screenRect(of: current.rect, in: panel.frame)
        let oldWindow = panel.frame
        change()
        restGeneration += 1
        let mine = restGeneration
        let l = layout, visible = visibleFrame
        let union = EdgeGeometry.inflated(from.union(l.restWindow(in: visible)), by: Tokens.Motion.overshootMargin)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { panel.setFrame(union, display: true) }
        var start = current
        start.rect = EdgeGeometry.localRect(of: from, in: union)
        start.fusion?.x += oldWindow.minX - union.minX
        let curve = motionCurve
        presentation.beginRestMove(
            from: start, to: l.restSpec(in: union, screen: visible), pane: l.paneSpec(in: union, screen: visible), curve: curve
        )
        host.layoutSubtreeIfNeeded()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(curve.settlingTime))
            self?.finishRest(mine)
        }
    }

    private func finishRest(_ generation: Int) {
        guard restGeneration == generation, machine.phase == .collapsed else { return }
        presentation.endRestMove()
        settle(window: layout.restWindow(in: visibleFrame))
    }

    func screenRect(of local: CGRect, in window: CGRect) -> CGRect {
        CGRect(x: window.minX + local.minX, y: window.maxY - local.maxY, width: local.width, height: local.height)
    }

    // MARK: Peeking

    /// A docked tab grows into the capsule under the pointer, so what is in it can be seen and clicked.
    func beginPeek() {
        peekEnd?.cancel()
        guard settings.mode == .docked, machine.phase == .collapsed, !peeking, drag == nil else { return }
        transitionRest { peeking = true }
    }

    func scheduleEndPeek() {
        peekEnd?.cancel()
        guard peeking else { return }
        peekEnd = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Tokens.Motion.peekGrace)
            guard !Task.isCancelled else { return }
            self?.endPeek()
        }
    }

    private func endPeek() {
        guard peeking, drag == nil, machine.phase == .collapsed else { return }
        tooltips.hide()
        presentation.hoveredDot = nil
        transitionRest { peeking = false }
    }

    /// Docks on an edge at a height, the capsule folding into the tab.
    func dock(on edge: PanelEdge, anchor: CGFloat) {
        transitionRest {
            settings.mode = .docked
            settings.edge = edge
            settings.anchor = anchor
            peeking = false
        }
    }

    // MARK: Docking from the menu

    /// Docks on the chosen edge, at the height it had.
    public func setEdge(_ edge: PanelEdge) {
        guard edge != settings.edge || settings.mode != .docked else { return }
        transitionRest {
            settings.mode = .docked
            settings.edge = edge
            peeking = false
        }
        settings.save(to: defaults)
        if machine.phase != .collapsed { settle(window: layout.paneFrame(in: visibleFrame)) }
    }

    // MARK: Dragging

    func dragEvent(_ phase: DragPhase) {
        guard machine.phase == .collapsed else { return }
        let mouse = NSEvent.mouseLocation
        switch phase {
        case .changed:
            if drag == nil { beginDrag(at: mouse) }
            continueDrag(at: mouse)
        case .ended:
            endDrag(at: mouse)
        }
    }

    private func beginDrag(at mouse: CGPoint) {
        tooltips.hide()
        peekEnd?.cancel()
        presentation.hoveredDot = nil
        let frame = panel.frame
        drag = DragState(offset: CGPoint(x: frame.midX - mouse.x, y: frame.midY - mouse.y))
    }

    private func continueDrag(at mouse: CGPoint) {
        guard var state = drag else { return }
        let visible = visibleFrame
        let items = model.items
        let current = layout
        let step = DockGeometry.dragStep(
            raw: CGPoint(x: mouse.x + state.offset.x, y: mouse.y + state.offset.y), mode: settings.mode, edge: settings.edge,
            floatCenter: settings.floatCenter, orientation: orientation, dotCount: items.count,
            hasOverflow: items.count > Tokens.Capsule.maximumDots,
            restingCenterX: { edge in
                var docked = current
                docked.mode = .docked
                docked.peeking = true
                docked.edge = edge
                return docked.restFrame(in: visible).midX
            }, in: visible
        )
        guard step.moved else { return }
        settings.mode = step.mode
        settings.floatCenter = step.floatCenter
        orientation = step.orientation
        peeking = false
        state.moved = true
        drag = state
        settle(window: layout.restWindow(in: visible))
    }

    private func endDrag(at mouse: CGPoint) {
        guard let state = drag else { return }
        drag = nil
        presentation.clicksIgnoredUntil = Date().addingTimeInterval(Tokens.Motion.clickGuard)
        guard state.moved, settings.mode == .floating else {
            settings.save(to: defaults)
            return
        }
        let raw = CGPoint(x: mouse.x + state.offset.x, y: mouse.y + state.offset.y)
        switch DockGeometry.snap(dragCenter: raw, in: visibleFrame) {
        case .dock(let edge, let anchor):
            dock(on: edge, anchor: anchor)
        case .float(let center):
            settings.floatCenter = center
        }
        settings.save(to: defaults)
    }
}
