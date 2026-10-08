import Foundation

public enum LocatorRejection: Error, Equatable, Sendable {
    case malformedURL(String)
    case insecureWebURL(String)
    case disallowedScheme(String)
    case unsupportedEditor(String)
    case invalidWorkspacePath
    case invalidEditorPosition
}

/// Gatekeeper applied before Porter hands any locator to the system to open.
/// Deep-link schemes are opt-in per verified app; none are trusted by default.
public struct LocatorPolicy: Sendable {
    public static let vscodeBundleId = "com.microsoft.VSCode"
    private static let webScheme = "https"
    private static let neverOpenedSchemes: Set<String> = ["file", "http", "javascript", "data"]

    public let allowedDeepLinkSchemes: Set<String>

    public init(allowedDeepLinkSchemes: Set<String> = []) {
        self.allowedDeepLinkSchemes = allowedDeepLinkSchemes.subtracting(Self.neverOpenedSchemes)
    }

    public func validate(_ locator: Locator) throws(LocatorRejection) {
        switch locator {
        case .browserTab(let tab):
            if let url = tab.canonicalUrl { try requireWeb(url) }
        case .desktopLink(let link):
            if link.bundleId == DesktopLinks.claudeBundleId, DesktopLinks.isAllowedClaudeChatLink(link.deepLink) { return }
            try requireAllowedDeepLink(link.deepLink)
        case .mobileLink(let link):
            if try scheme(of: link.url) == Self.webScheme { return }
            try requireAllowedDeepLink(link.url)
        case .editorTab(let editor):
            try requireEditorTab(editor)
        }
    }

    /// Only an editor Porter knows how to bring forward, and only a plain absolute folder path.
    private func requireEditorTab(_ editor: EditorTabLocator) throws(LocatorRejection) {
        guard editor.bundleId == Self.vscodeBundleId else { throw .unsupportedEditor(editor.bundleId) }
        guard BridgeValidation.isWorkspacePath(editor.workspacePath) else { throw .invalidWorkspacePath }
        guard (1...8).contains(editor.viewColumn), (0...8).contains(editor.index) else { throw .invalidEditorPosition }
    }

    private func requireWeb(_ text: String) throws(LocatorRejection) {
        guard try scheme(of: text) == Self.webScheme else { throw .insecureWebURL(text) }
    }

    private func requireAllowedDeepLink(_ text: String) throws(LocatorRejection) {
        let scheme = try scheme(of: text)
        guard allowedDeepLinkSchemes.contains(scheme) else { throw .disallowedScheme(scheme) }
    }

    private func scheme(of text: String) throws(LocatorRejection) -> String {
        guard let scheme = URL(string: text)?.scheme?.lowercased() else { throw .malformedURL(text) }
        return scheme
    }
}
