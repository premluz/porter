import Foundation

/// How a provider is written for people. Unknown providers fall back to their identifier, shown
/// as-is rather than guessed at.
public enum ProviderNames {
    private static let names = ["claude": "Claude", "chatgpt": "ChatGPT"]

    public static func display(_ provider: String) -> String {
        names[provider] ?? provider
    }
}
