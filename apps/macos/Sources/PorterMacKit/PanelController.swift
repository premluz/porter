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
    private let host: NSHostingView<PanelRootView>
    private var screen: NSScreen?
    private var resignObserver: (any NSObjectProtocol)?

    public init(model: AppModel, settings: PanelSettings, defaults: UserDefaults = .standard) {
        self.model = model
        self.settings = settings
        self.defaults = defaults
        presentation.edge = settings.edge
        host = NSHostingView(rootView: PanelRootView(model: model, presentation: presentation, expand: {}, close: {}))
        host.sizingOptions = []
        panel.contentView = host
        panel.onCancel = { [weak self] in self?.close() }
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

    public func open() {
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
            let sections = [model.snapshot.pinned, model.snapshot.open].filter { !$0.isEmpty }.count
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

    /// Positions the window and the shapes inside it without any animation, so nothing visibly moves.
    private func settle(window: CGRect) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            panel.setFrame(window, display: true)
            presentation.layout(window: window, capsuleFrame: frame(expanded: false), paneFrame: frame(expanded: true))
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
        if machine.phase == .expanded {
            settle(window: frame(expanded: true))
            Task { @MainActor [weak self] in self?.presentation.refreshSurface() }
        }
        finishIfCollapsed()
    }

    /// Once fully collapsed the window shrinks to the capsule, so no transparent area remains.
    private func finishIfCollapsed() {
        guard machine.phase == .collapsed else { return }
        settle(window: frame(expanded: false))
        panel.allowsKey = false
        panel.resignKey()
        // After the resize and the key change have both been applied, so the glass is rebuilt last.
        Task { @MainActor [weak self] in self?.presentation.refreshSurface() }
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
