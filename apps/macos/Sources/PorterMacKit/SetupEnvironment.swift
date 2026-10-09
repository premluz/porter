import AppKit
import Foundation

/// Facts about this Mac the setup window reports. Reading them changes nothing.
public enum SetupEnvironment {
    public struct Editor: Sendable, Equatable {
        public let name: String
        public let bundleId: String
        let cliName: String
        let applicationPath: String

        /// The command the editor ships for installing extensions from a file.
        public var cliPath: String { applicationPath + "/Contents/Resources/app/bin/" + cliName }
    }

    /// VS Code and the editors built on it: the bundle id each ships with, and the name of its install command.
    private static let known: [(name: String, bundleId: String, cli: String)] = [
        ("VS Code", "com.microsoft.VSCode", "code"),
        ("Cursor", "com.todesktop.230313mzl4w4u92", "cursor"),
        ("Windsurf", "com.exafunction.windsurf", "devin-desktop"),
    ]

    public static func installedEditors() -> [Editor] {
        known.compactMap { entry in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: entry.bundleId) else { return nil }
            let editor = Editor(name: entry.name, bundleId: entry.bundleId, cliName: entry.cli, applicationPath: url.path)
            return FileManager.default.isExecutableFile(atPath: editor.cliPath) ? editor : nil
        }
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
