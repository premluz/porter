import AppKit
import SwiftUI

/// Owns the one panel window. The window is sized once per move, to the pane while it is open or
/// closing and to the capsule when settled, and a spring animates the glass shape inside it. The
/// window is therefore never resized frame by frame, which was the cause of visible jitter.
@MainActor
public final class PanelController {
    public private(set) var settings: PanelSettings
    private(set) var machine = PanelStateMachine()
    let panel = PanelWindow()
    let model: AppModel
    let presentation = PanelPresentation()
    private let defaults: UserDefaults
    private let host: TrackingHostingView<PanelRootView>
    private let tooltips = TooltipController()
    private var showingHand = false
    private var screen: NSScreen?
    private var resignObserver: (any NSObjectProtocol)?

    public init(model: AppModel, settings: PanelSettings, defaults: UserDefaults = .standard) {
        self.model = model
        self.settings = settings
        self.defaults = defaults
        presentation.edge = settings.edge
        host = TrackingHostingView(rootView: PanelRootView(model: model, presentation: presentation, expand: {}, close: {}))
        host.sizingOptions = []
        panel.contentView = host
        panel.onCancel = { [weak self] in self?.close() }
        panel.acceptsMouseMovedEvents = true
        host.onPointer = { [weak self] point in self?.pointerMoved(to: point) }
        host.cursorAt = { [weak self] point in self?.cursor(at: point) }
        host.rootView = PanelRootView(
            model: model, presentation: presentation, expand: { [weak self] in self?.open() }, close: { [weak self] in self?.close() }
        )
        model.onHandoff = { [weak self] in self?.close() }
        model.onContentChanged = { [weak self] in self?.contentChanged() }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.close() } }
    }

    /// Shows the capsule without activating anything or taking focus.
    public func show() {
        settle(window: frame(expanded: false))
        panel.orderFrontRegardless()
    }

    public func toggle() {
        if machine.isExpandedOrOpening { close() } else { open() }
    }

    /// What is under the pointer: in the collapsed capsule a dot or the open button, in the open pane a row of the list.
    private func clickable(at point: CGPoint) -> String? {
        switch machine.phase {
        case .collapsed:
            return CapsuleHover.item(at: point, frames: presentation.dotFrames)
        case .expanded:
            // Rows scrolled under the search field or the footer are still laid out, so only the visible list counts.
            guard presentation.listFrame.contains(point) else { return nil }
            return CapsuleHover.item(at: point, frames: presentation.rowFrames, horizontalReach: 0, verticalReach: 0)
        default:
            return nil
        }
    }

    /// A dot, the open button and a row take a click, so they show the pointing hand. Collapsed, everything else is the
    /// arrow; open, the arrow is restored once on leaving a row and otherwise the views underneath choose.
    private func cursor(at point: CGPoint) -> NSCursor? {
        if clickable(at: point) != nil {
            showingHand = true
            return .pointingHand
        }
        defer { showingHand = false }
        return machine.phase == .collapsed || showingHand ? .arrow : nil
    }

    /// Collapsed, the dot under the pointer is lit and its label shown at once; the label glides to the next dot and
    /// leaves only when the pointer leaves the dots altogether.
    private func pointerMoved(to point: CGPoint?) {
        let hit = point.flatMap(clickable(at:))
        let collapsed = machine.phase == .collapsed
        let dot = collapsed ? hit : nil
        let row = collapsed ? nil : hit
        if presentation.hoveredDot != dot { presentation.hoveredDot = dot }
        if presentation.hoveredRow != row { presentation.hoveredRow = row }
        guard collapsed, let hit, let item = model.items.first(where: { $0.id == hit }), let frame = presentation.dotFrames[hit] else {
            tooltips.hide()
            return
        }
        let visible = (screen ?? NSScreen.main)?.visibleFrame ?? panel.frame
        tooltips.show(
            item, anchor: CapsuleHover.screenRect(of: frame, inWindow: panel.frame), window: panel.frame,
            edge: settings.edge, visible: visible
        )
    }

    public func open() {
        tooltips.hide()
        presentation.hoveredDot = nil
        guard let animation = machine.open() else { return }
        screen = screenUnderPointer()
        panel.allowsKey = true
        // Room around the pane for the bounce to overshoot into; trimmed back once it has settled.
        settle(window: EdgeGeometry.inflated(frame(expanded: true), by: Tokens.Motion.overshootMargin))
        panel.makeKeyAndOrderFront(nil)
        model.paneVisibilityChanged(visible: true)
        animate(to: true, animation)
    }

    public func close() {
        presentation.hoveredRow = nil
        guard let animation = machine.close() else { return }
        model.paneVisibilityChanged(visible: false)
        animate(to: false, animation)
    }

    public func setEdge(_ edge: PanelEdge) {
        guard edge != settings.edge else { return }
        settings.edge = edge
        settings.save(to: defaults)
        presentation.edge = edge
        settle(window: frame(expanded: machine.isExpandedOrOpening))
    }

    /// Frame for either shape on the current screen. Exposed so tests can compare real windows to geometry.
    func frame(expanded: Bool) -> CGRect {
        let visible = (screen ?? NSScreen.main)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let items = model.items
        if expanded {
            let split = model.snapshot.recentSplit()
            let sections = [model.snapshot.needsYou, model.snapshot.pinned, split.older].filter { !$0.isEmpty }.count + model.recentGroups.count
            let rows = items.isEmpty ? 3 : items.count
            return EdgeGeometry.paneFrame(in: visible, edge: settings.edge, anchor: settings.anchor, rowCount: rows, sectionCount: sections)
        }
        return EdgeGeometry.capsuleFrame(
            in: visible, edge: settings.edge, anchor: settings.anchor,
            dotCount: items.count, hasOverflow: items.count > Tokens.Capsule.maximumDots
        )
    }

    /// Jumps straight to a state with no animation; used in the self test.
    func applyInstantly(expanded: Bool) {
        let animation = expanded ? machine.open() : machine.close()
        settle(window: frame(expanded: expanded))
        presentation.snap(expanded: expanded)
        if let animation { machine.finished(animation) }
        finishIfCollapsed()
    }

    /// The two shapes in a window's own coordinates: where the panel rests and where it opens to.
    private func specs(in window: CGRect) -> (rest: ShapeSpec, pane: ShapeSpec) {
        (
            ShapeSpec(
                rect: EdgeGeometry.localRect(of: frame(expanded: false), in: window), corner: Tokens.Size.capsuleCorner,
                edge: settings.edge, kind: .capsule(.vertical)
            ),
            ShapeSpec(
                rect: EdgeGeometry.localRect(of: frame(expanded: true), in: window), corner: Tokens.Size.paneCorner,
                edge: settings.edge, kind: .pane
            )
        )
    }

    /// Positions the window and the shapes inside it without any animation, so nothing visibly moves.
    private func settle(window: CGRect) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            panel.setFrame(window, display: true)
            let shapes = specs(in: window)
            presentation.layout(rest: shapes.rest, pane: shapes.pane)
        }
        host.layoutSubtreeIfNeeded()
    }

    private func animate(to expanded: Bool, _ animation: PanelAnimation) {
        let curve = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? SpringCurve(duration: Tokens.Motion.reducedDuration, bounce: 0)
            : SpringCurve(duration: Tokens.Motion.springDuration, bounce: Tokens.Motion.springBounce)
        presentation.beginMove(expanded: expanded, curve: curve)
        // A reversal starts a new move and a new generation, so this move's completion is then ignored.
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(curve.settlingTime))
            self?.complete(animation)
        }
    }

    private func complete(_ animation: PanelAnimation) {
        guard machine.finished(animation) else { return }
        presentation.endMove()
        if machine.phase == .expanded { settle(window: frame(expanded: true)) }
        finishIfCollapsed()
    }

    /// Once fully collapsed the window shrinks to the capsule, so no transparent area remains.
    private func finishIfCollapsed() {
        guard machine.phase == .collapsed else { return }
        settle(window: frame(expanded: false))
        panel.allowsKey = false
        panel.resignKey()
    }

    private func contentChanged() {
        guard machine.phase == .collapsed else { return }
        settle(window: frame(expanded: false))
    }

    private func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
    }
}
