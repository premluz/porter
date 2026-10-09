import Foundation

public struct ConversationMatch: Sendable, Equatable {
    public let providerConversationId: String
    public let canonicalUrl: String
}

/// A provider's identity rules, the same ones the browser extension's adapters apply. Recognizers read
/// only a URL and a title: no page content, so a provider changing its layout cannot change what is
/// reported. Adding a model is adding an entry to `ProviderRecognizers.all`, plus tests.
public protocol ProviderRecognizer: Sendable {
    var provider: String { get }
    var displayName: String { get }
    var adapterVersion: String { get }
    /// False until a real page of this provider has been checked against these rules.
    var verified: Bool { get }
    /// Web hosts this provider's conversations live on, so a source can ask a browser only for those tabs.
    var hosts: [String] { get }
    func match(url rawUrl: String?) -> ConversationMatch?
    func cleanTitle(_ raw: String?) -> String
}

/// A provider whose conversations live at `https://<host>/<pathPrefix>/<id>`.
public struct PathProviderRecognizer: ProviderRecognizer {
    public let provider: String
    public let displayName: String
    public let adapterVersion: String
    public let verified: Bool
    let host: String
    let pathPrefix: String

    public var hosts: [String] { [host] }

    private static let untitled = "Untitled conversation"
    private static let identifierCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")

    public func match(url rawUrl: String?) -> ConversationMatch? {
        guard let rawUrl, let parts = URLComponents(string: rawUrl),
              parts.scheme == "https", parts.host?.lowercased() == host, parts.port == nil else { return nil }
        let prefix = "/\(pathPrefix)/"
        guard parts.percentEncodedPath.hasPrefix(prefix) else { return nil }
        let id = String(parts.percentEncodedPath.dropFirst(prefix.count))
        guard (1...BridgeLimits.maximumIdentifierLength).contains(id.count),
              id.unicodeScalars.allSatisfy(Self.identifierCharacters.contains) else { return nil }
        return ConversationMatch(providerConversationId: id, canonicalUrl: "https://\(host)/\(pathPrefix)/\(id)")
    }

    /// Titles are display data only. The provider's "- Name" suffix is dropped when present.
    public func cleanTitle(_ raw: String?) -> String {
        let suffix = try? NSRegularExpression(pattern: "\\s+[-|–]\\s+\(NSRegularExpression.escapedPattern(for: displayName))$")
        let text = raw ?? ""
        let range = NSRange(text.startIndex..., in: text)
        let stripped = (suffix?.stringByReplacingMatches(in: text, range: range, withTemplate: "") ?? text)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty, stripped != displayName else { return Self.untitled }
        return String(stripped.prefix(BridgeLimits.maximumTitleLength))
    }
}

public enum ProviderRecognizers {
    public static let claude = PathProviderRecognizer(
        provider: "claude", displayName: "Claude", adapterVersion: "0.1.0", verified: true, host: "claude.ai", pathPrefix: "chat"
    )
    /// UNVERIFIED: the /c/<id> shape is the one chatgpt.com has used, not checked against a live page here.
    public static let chatgpt = PathProviderRecognizer(
        provider: "chatgpt", displayName: "ChatGPT", adapterVersion: "0.1.0", verified: false, host: "chatgpt.com", pathPrefix: "c"
    )

    public static let all: [any ProviderRecognizer] = [claude, chatgpt]

    public static func recognizer(for provider: String) -> (any ProviderRecognizer)? {
        all.first { $0.provider == provider }
    }

    /// First recognizer whose rules accept the URL. Rules are exact, so two never both match.
    public static func recognize(url rawUrl: String?) -> (recognizer: any ProviderRecognizer, match: ConversationMatch)? {
        for recognizer in all {
            if let match = recognizer.match(url: rawUrl) { return (recognizer, match) }
        }
        return nil
    }

    public static var adapterVersions: [String: String] {
        Dictionary(uniqueKeysWithValues: all.map { ($0.provider, $0.adapterVersion) })
    }
}
