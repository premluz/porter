import AppKit
import Foundation

/// The real-world side of recovery buttons. Both are explicit user actions.
@MainActor
public final class WorkspaceRecoveryPerformer: RecoveryPerformer {
    static let chromeBundleIdentifier = "com.google.Chrome"

    public init() {}

    /// May open a different profile or account than the one the shortcut came from; the button says so.
    public func openInDefaultBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    public func openInDesktopApp(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    public func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    public func launchBrowser() {
        guard let chrome = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.chromeBundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: chrome, configuration: NSWorkspace.OpenConfiguration())
    }
}
