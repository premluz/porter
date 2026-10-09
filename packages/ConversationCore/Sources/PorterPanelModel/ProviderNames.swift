import Foundation

/// How a provider is written for people. Unknown providers fall back to their identifier, shown
/// as-is rather than guessed at.
/// The application a conversation lives in, which is what "reconnect" means for it.
public enum HostApplication: String, Sendable, Equatable {
    case chrome, vscode, claudeApp, chatgptApp

    public var displayName: String {
        switch self {
        case .chrome: "Chrome"
        case .vscode: "VS Code"
        case .claudeApp: "Claude"
        case .chatgptApp: "ChatGPT"
        }
    }

    public var bundleIdentifier: String {
        switch self {
        case .chrome: "com.google.Chrome"
        case .vscode: "com.microsoft.VSCode"
        case .claudeApp: "com.anthropic.claudefordesktop"
        case .chatgptApp: "com.openai.codex"
        }
    }

    /// Applications whose conversations are listed in their own window rather than in a browser.
    public var isDesktopChatApp: Bool { self == .claudeApp || self == .chatgptApp }
}

public enum ProviderNames {
    /// Claude Code conversations are editor tabs, the desktop apps list their own, and the rest are browser tabs.
    public static func host(for provider: String) -> HostApplication {
        if editorProviders.contains(provider) { return .vscode }
        return desktopProviders[provider] ?? .chrome
    }

    private static let desktopProviders: [String: HostApplication] = ["claude-desktop": .claudeApp, "chatgpt-desktop": .chatgptApp]

    private static let editorProviders: Set<String> = ["claude-code", "codex"]

    private static let names = ["claude": "Claude", "chatgpt": "ChatGPT", "claude-code": "Claude Code", "codex": "ChatGPT Codex", "claude-desktop": "Claude app", "chatgpt-desktop": "ChatGPT app"]

    public static func display(_ provider: String) -> String {
        names[provider] ?? provider
    }
}
