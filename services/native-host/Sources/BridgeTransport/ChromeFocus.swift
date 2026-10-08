import AppKit

/// The extension raises the tab and window inside Chrome; this asks macOS to bring the Chrome
/// application forward. Whether a background process may do that is measured, not assumed, so the
/// outcome string is reported back instead of being treated as success.
public enum ChromeFocus {
    public static let chromeBundleIdentifier = "com.google.Chrome"

    public static func requestForeground() -> String {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: chromeBundleIdentifier)
        guard let chrome = running.first else { return "chromeNotRunning" }
        return chrome.activate() ? "requested" : "refusedByMacOS"
    }
}
