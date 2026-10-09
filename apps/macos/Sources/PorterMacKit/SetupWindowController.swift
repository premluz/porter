import AppKit
import SwiftUI

/// The setup window. Closing it never stops anything; Porter runs without it open.
@MainActor
public final class SetupWindowController {
    private static let shownKey = "porter.setup.shown"
    private static let refreshInterval: Duration = .seconds(2)

    private let model: SetupModel
    private let defaults: UserDefaults
    private var window: NSWindow?
    private var refresher: Task<Void, Never>?

    public init(model: SetupModel, defaults: UserDefaults = .standard) {
        self.model = model
        self.defaults = defaults
    }

    /// Opens the window on the first launch only; later it is the menu item's job.
    public func showOnFirstLaunch() {
        guard !defaults.bool(forKey: Self.shownKey) else { return }
        defaults.set(true, forKey: Self.shownKey)
        show()
    }

    public func show() {
        let window = window ?? makeWindow()
        self.window = window
        model.refresh()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        refresher?.cancel()
        refresher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.refreshInterval)
                self?.model.refresh()
            }
        }
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: SetupView(model: model))
        let window = NSWindow(contentViewController: host)
        window.title = "Set up Porter"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresher?.cancel() }
        }
        return window
    }
}
