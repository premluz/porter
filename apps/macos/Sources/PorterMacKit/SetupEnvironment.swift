import AppKit
import Foundation

/// Facts about this Mac the setup window reports. Reading them changes nothing.
enum SetupEnvironment {
    /// VS Code and the editors built on it, by the bundle id each one ships with.
    static let editors: [(name: String, bundleId: String)] = [
        ("VS Code", "com.microsoft.VSCode"),
        ("Cursor", "com.todesktop.230313mzl4w4u92"),
        ("Windsurf", "com.exafunction.windsurf"),
    ]

    static func installedEditors() -> [String] {
        editors.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleId) != nil }.map(\.name)
    }

    static let hookMarker = "porterctl hook"

    /// Whether Claude Code's settings carry Porter's hook. Nil when the file exists but cannot be read, so the
    /// window says nothing rather than guess; a missing file means no hook.
    static func claudeCodeHookInstalled(settingsPath: String = NSHomeDirectory() + "/.claude/settings.json") -> Bool? {
        guard FileManager.default.fileExists(atPath: settingsPath) else { return false }
        guard let data = FileManager.default.contents(atPath: settingsPath) else { return nil }
        return String(decoding: data, as: UTF8.self).contains(hookMarker)
    }
}
