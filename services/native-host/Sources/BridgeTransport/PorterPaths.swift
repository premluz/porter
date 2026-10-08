import Foundation

public enum PorterPaths {
    static let supportDirectoryVariable = "PORTER_SUPPORT_DIR"
    static let applicationSupportName = "Porter"

    /// The override exists for tests and for keeping socket paths under the 104-byte limit.
    public static func supportDirectory() -> String {
        if let override = ProcessInfo.processInfo.environment[supportDirectoryVariable], !override.isEmpty {
            return override
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/\(applicationSupportName)").path
    }

    public static func bridgeSocket() -> String { supportDirectory() + "/bridge.sock" }

    public static func controlSocket() -> String { supportDirectory() + "/control.sock" }

    /// One `chrome-extension://<id>/` origin per line, written by the install script.
    public static func allowedOriginsFile() -> String { supportDirectory() + "/allowed-origins.txt" }
}
