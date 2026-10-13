import AppKit
import SwiftUI

/// Owns the one panel window. The window is sized once per move, to cover the shapes the move goes between, and a
/// spring animates the one shape inside it; at rest the window is exactly the shape, so no transparent area swallows
/// clicks meant for what is underneath. The window is never resized frame by frame, which was the cause of jitter.
/// The panel rests as a docked tab on a screen edge, as a capsule floating where it was left, or opens as the pane.
@MainActor
public final class PanelController {
    public internal(set) var settings: PanelSettings
    private(set) var machine = PanelStateMachine()
    let panel = PanelWindow()
    let model: AppModel
    let presentation = PanelPresentation()
    let defaults: UserDefaults
    let host: TrackingHostingView<PanelRootView>
    let tooltips = TooltipController()
    var showingHand = false
    var screen: NSScreen?
    /// A docked tab that has grown into the capsule because the pointer is on it.
    var peeking = false
    var orientation = PanelOrientation.vertical
    var restGeneration = 0
    var drag: DragState?
    var peekEnd: Task<Void, Never>?
    private var resignObserver: (any NSObjectProtocol)?

    public init(model: AppModel, settings: PanelSettings, defaults: UserDefaults = .standard) {
        self.model = model
        self.settings = settings
        self.defaults = defaults
        host = TrackingHostingView(rootView: PanelRootView(model: model, presentation: presentation, expand: {}, close: {}))
        host.sizingOptions = []
        panel.contentView = host
        panel.onCancel = { [weak self] in self?.close() }
        panel.acceptsMouseMovedEvents = true
        host.onPointer = { [weak self] point in self?.pointerMoved(to: point) }
        host.cursorAt = { [weak self] point in self?.cursor(at: point) }
        presentation.onDrag = { [weak self] phase in self?.dragEvent(phase) }
        host.rootView = PanelRootView(
            model: model, presentation: presentation, expand: { [weak self] in self?.open() }, close: { [weak self] in self?.close() }
        )
        model.onHandoff = { [weak self] in self?.close() }
        model.onContentChanged = { [weak self] in self?.contentChanged() }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.close() } }
    }

    // MARK: Layout

    var visibleFrame: CGRect {
        (screen ?? NSScreen.main)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    /// Everything that decides where the shapes are, from the settings and what the panel is showing.
    var layout: PanelLayout {
        let items = model.items
        let split = model.snapshot.recentSplit()
        let sections = [model.snapshot.needsYou, model.snapshot.pinned, split.older].filter { !$0.isEmpty }.count + model.recentGroups.count
        return PanelLayout(
            mode: settings.mode, edge: settings.edge, anchor: settings.anchor, floatCenter: settings.floatCenter,
            orientation: orientation, peeking: peeking, dotCount: items.count, hasOverflow: items.count > Tokens.Capsule.maximumDots,
            rowCount: items.isEmpty ? 3 : items.count, sectionCount: sections
        )
    }

    /// Frame for either shape on the current screen. Exposed so tests can compare real windows to geometry.
    func frame(expanded: Bool) -> CGRect {
        expanded ? layout.paneFrame(in: visibleFrame) : layout.restFrame(in: visibleFrame)
    }

    /// The window while the panel is open or opening: the pane and the resting shape it grows from, with room for the bounce.
    private func operatingWindow(_ layout: PanelLayout) -> CGRect {
        let visible = visibleFrame
        return EdgeGeometry.inflated(layout.paneFrame(in: visible).union(layout.restWindow(in: visible)), by: Tokens.Motion.overshootMargin)
    }

    /// Positions the window and the shapes inside it without any animation, so nothing visibly moves.
    func settle(window: CGRect) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            panel.setFrame(window, display: true)
            let l = layout, visible = visibleFrame
            presentation.layout(rest: l.restSpec(in: window, screen: visible), pane: l.paneSpec(in: window, screen: visible))
        }
        host.layoutSubtreeIfNeeded()
    }

    // MARK: Showing, opening and closing

    /// Shows the panel at rest without activating anything or taking focus.
    public func show() {
        screen = screenUnderPointer()
        settle(window: layout.restWindow(in: visibleFrame))
        panel.orderFrontRegardless()
    }

    public func toggle() {
        if machine.isExpandedOrOpening { close() } else { open() }
    }

    public func open() {
        tooltips.hide()
        peekEnd?.cancel()
        presentation.hoveredDot = nil
        guard let animation = machine.open() else { return }
        screen = screenUnderPointer()
        panel.allowsKey = true
        settle(window: operatingWindow(layout))
        panel.makeKeyAndOrderFront(nil)
        model.paneVisibilityChanged(visible: true)
        animate(to: true, animation)
    }

    public func close() {
        presentation.hoveredRow = nil
        guard let animation = machine.close() else { return }
        model.paneVisibilityChanged(visible: false)
        // A docked tab that peeked to be opened goes back to being a tab, so closing folds the pane into the tab.
        if peeking {
            peeking = false
            let l = layout, visible = visibleFrame
            presentation.replaceRest(l.restSpec(in: panel.frame, screen: visible))
        }
        animate(to: false, animation)
    }

    /// Jumps straight to a state with no animation; used in the self test.
    func applyInstantly(expanded: Bool) {
        let animation = expanded ? machine.open() : machine.close()
        settle(window: expanded ? layout.paneFrame(in: visibleFrame) : layout.restWindow(in: visibleFrame))
        presentation.snap(expanded: expanded)
        if let animation { machine.finished(animation) }
        finishIfCollapsed()
    }

    private func animate(to expanded: Bool, _ animation: PanelAnimation) {
        presentation.beginMove(expanded: expanded, curve: motionCurve)
        // A reversal starts a new move and a new generation, so this move's completion is then ignored.
        let curve = motionCurve
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(curve.settlingTime))
            self?.complete(animation)
        }
    }

    var motionCurve: SpringCurve {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? SpringCurve(duration: Tokens.Motion.reducedDuration, bounce: 0)
            : SpringCurve(duration: Tokens.Motion.springDuration, bounce: Tokens.Motion.springBounce)
    }

    private func complete(_ animation: PanelAnimation) {
        guard machine.finished(animation) else { return }
        presentation.endMove()
        if machine.phase == .expanded { settle(window: layout.paneFrame(in: visibleFrame)) }
        finishIfCollapsed()
    }

    /// Once fully collapsed the window shrinks to the resting shape, so no transparent area remains.
    private func finishIfCollapsed() {
        guard machine.phase == .collapsed else { return }
        settle(window: layout.restWindow(in: visibleFrame))
        panel.allowsKey = false
        panel.resignKey()
    }

    private func contentChanged() {
        guard machine.phase == .collapsed, drag == nil, !presentation.isRestMoving else { return }
        settle(window: layout.restWindow(in: visibleFrame))
    }

    func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
    }
}
