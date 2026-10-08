import Foundation

/// How a provider is written for people. Unknown providers fall back to their identifier, shown
/// as-is rather than guessed at.
/// The application a conversation lives in, which is what "reconnect" means for it.
public enum HostApplication: String, Sendable, Equatable {
    case chrome, vscode

    public var displayName: String {
        switch self {
        case .chrome: "Chrome"
        case .vscode: "VS Code"
        }
    }

    public var bundleIdentifier: String {
        switch self {
        case .chrome: "com.google.Chrome"
        case .vscode: "com.microsoft.VSCode"
        }
    }
}

public enum ProviderNames {
    /// Claude Code conversations are editor tabs; everything else Porter lists is a browser tab.
    public static func host(for provider: String) -> HostApplication {
        provider == "claude-code" ? .vscode : .chrome
    }

    private static let names = ["claude": "Claude", "chatgpt": "ChatGPT", "claude-code": "Claude Code"]

    public static func display(_ provider: String) -> String {
        names[provider] ?? provider
    }
}
