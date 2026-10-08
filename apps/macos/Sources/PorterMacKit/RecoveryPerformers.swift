import AppKit
import Foundation
import PorterPanelModel

/// The real-world side of recovery buttons. Both are explicit user actions.
@MainActor
public final class WorkspaceRecoveryPerformer: RecoveryPerformer {
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

    public func launch(_ host: HostApplication) {
        guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: host.bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: application, configuration: NSWorkspace.OpenConfiguration())
    }
}
