import AppKit
import SwiftUI

/// Owns the one panel window and moves it between capsule and pane. The window is always exactly
/// the visible shape, so it never covers desktop area it is not drawing.
@MainActor
public final class PanelController {
    public private(set) var settings: PanelSettings
    private(set) var machine = PanelStateMachine()
    let panel = PanelWindow()
    let model: AppModel
    private let defaults: UserDefaults
    private let host: NSHostingView<PanelRootView>
    private var screen: NSScreen?
    private var resignObserver: (any NSObjectProtocol)?

    public init(model: AppModel, settings: PanelSettings, defaults: UserDefaults = .standard) {
        self.model = model
        self.settings = settings
        self.defaults = defaults
        host = NSHostingView(rootView: PanelRootView(model: model, edge: settings.edge, expand: {}, close: {}))
        host.sizingOptions = []
        panel.contentView = host
        panel.onCancel = { [weak self] in self?.close() }
        install(edge: settings.edge)
        model.onHandoff = { [weak self] in self?.close() }
        model.onContentChanged = { [weak self] in self?.contentChanged() }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.close() } }
    }

    /// Shows the capsule without activating anything or taking focus.
    public func show() {
        panel.setFrame(frame(expanded: false), display: true)
        panel.orderFrontRegardless()
    }

    public func toggle() {
        if machine.isExpandedOrOpening { close() } else { open() }
    }

    public func open() {
        guard let animation = machine.open() else { return }
        screen = screenUnderPointer()
        panel.allowsKey = true
        panel.makeKeyAndOrderFront(nil)
        model.paneVisibilityChanged(visible: true)
        animate(animation, to: frame(expanded: true))
    }

    public func close() {
        guard let animation = machine.close() else { return }
        model.paneVisibilityChanged(visible: false)
        animate(animation, to: frame(expanded: false))
    }

    public func setEdge(_ edge: PanelEdge) {
        guard edge != settings.edge else { return }
        settings.edge = edge
        settings.save(to: defaults)
        install(edge: edge)
        panel.setFrame(frame(expanded: machine.isExpandedOrOpening), display: true)
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

    /// Jumps straight to a state with no animation; used for Reduce Motion and in the self test.
    func applyInstantly(expanded: Bool) {
        if expanded { _ = machine.open() } else { _ = machine.close() }
        panel.setFrame(frame(expanded: expanded), display: true)
        finishIfSettled()
    }

    private func animate(_ animation: PanelAnimation, to target: CGRect) {
        panel.allowsKey = machine.isExpandedOrOpening || panel.allowsKey
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(target, display: true)
            complete(animation)
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Tokens.Motion.duration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            Task { @MainActor in self?.complete(animation) }
        })
    }

    private func complete(_ animation: PanelAnimation) {
        guard machine.finished(animation) else { return }
        finishIfSettled()
    }

    private func finishIfSettled() {
        if machine.phase == .collapsed {
            panel.allowsKey = false
            panel.resignKey()
        }
    }

    private func contentChanged() {
        guard machine.phase == .collapsed else { return }
        panel.setFrame(frame(expanded: false), display: true)
    }

    private func install(edge: PanelEdge) {
        host.rootView = PanelRootView(
            model: model, edge: edge, expand: { [weak self] in self?.open() }, close: { [weak self] in self?.close() }
        )
    }

    private func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
    }
}
