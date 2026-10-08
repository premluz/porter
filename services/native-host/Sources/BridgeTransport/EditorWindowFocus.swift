import AppKit
import ConversationCore
import Foundation
import Synchronization

/// Brings a desktop editor's window for a folder forward by opening that folder. Opening a folder
/// that a window already shows focuses that window instead of creating another (observed with
/// VS Code, 2026-10-08), which is what lets a request reach the right window.
public enum EditorWindowFocus {
    /// Returns a short description for logs and the control reply; never throws, because failing to
    /// focus is reported by the connector's own check afterwards.
    public static func openWorkspace(_ preparation: ActivationPreparation) -> String {
        guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: preparation.bundleId) else {
            return "editorNotInstalled"
        }
        let folder = URL(fileURLWithPath: preparation.workspacePath)
        let semaphore = DispatchSemaphore(value: 0)
        let failure = Mutex<String?>(nil)
        NSWorkspace.shared.open([folder], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            failure.withLock { $0 = error.map { String(describing: $0) } }
            semaphore.signal()
        }
        semaphore.wait()
        return failure.withLock { $0 } ?? "workspaceOpened"
    }
}
