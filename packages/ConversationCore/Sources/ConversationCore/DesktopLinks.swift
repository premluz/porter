import Foundation

/// A link that asks a desktop app to show a chat. Porter can request it but never learns whether
/// the app opened the right chat or which account it is signed into.
public struct DesktopLink: Sendable, Equatable {
    public let bundleId: String
    public let url: String
}

/// Only documented shapes (docs/SOURCES.md, S12). Prefill and other forms are not built or accepted:
/// text must never reach a prompt through navigation.
public enum DesktopLinks {
    public static let claudeBundleId = "com.anthropic.claudefordesktop"
    public static let claudeProvider = "claude"
    private static let scheme = "claude"
    private static let host = "claude.ai"
    private static let chatPathPrefix = "/chat/"
    private static let maximumIdentifierLength = 128
    private static let identifierCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")

    /// `claude://claude.ai/chat/<id>`, or nil when the ID could not be a Claude chat ID.
    public static func claudeChat(providerConversationId: String) -> DesktopLink? {
        guard isSafeIdentifier(providerConversationId) else { return nil }
        return DesktopLink(bundleId: claudeBundleId, url: "\(scheme)://\(host)\(chatPathPrefix)\(providerConversationId)")
    }

    /// Exactly the documented chat link: no query, fragment, credentials, port or extra path.
    public static func isAllowedClaudeChatLink(_ text: String) -> Bool {
        guard let components = URLComponents(string: text),
              components.scheme == scheme, components.host == host,
              components.user == nil, components.password == nil, components.port == nil,
              components.query == nil, components.fragment == nil,
              components.path.hasPrefix(chatPathPrefix) else { return false }
        return isSafeIdentifier(String(components.path.dropFirst(chatPathPrefix.count)))
    }

    private static func isSafeIdentifier(_ text: String) -> Bool {
        (1...maximumIdentifierLength).contains(text.count) && text.unicodeScalars.allSatisfy(identifierCharacters.contains)
    }
}
