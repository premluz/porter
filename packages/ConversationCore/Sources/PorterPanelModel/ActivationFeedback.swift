import ConversationCore
import Foundation

/// A concrete next step after a failed open. Nothing here acts by itself.
public enum RecoveryAction: Sendable, Equatable {
    case tryAgain
    case refreshList
    case openHostApplication(HostApplication)
    case allowSiteAccess
    /// Opens the saved link in the default browser, which may be a different profile.
    case openSavedLinkInDefaultBrowser(url: String)
    /// Asks the desktop app to show the chat; it may be signed into a different account.
    case openInDesktopApp(url: String)
    case removeShortcut
}

public struct ActivationFeedback: Sendable, Equatable {
    public let title: String
    public let detail: String
    public let recovery: [RecoveryAction]
    /// True when the pane should close because the handoff happened.
    public let dismissesPane: Bool
}

public enum ActivationFeedbackBuilder {
    public static func feedback(for outcome: ActivationOutcome, item: PanelItem) -> ActivationFeedback {
        let saved = item.canonicalUrl.map(RecoveryAction.openSavedLinkInDefaultBrowser(url:))
        let desktop = item.desktopLink.map { RecoveryAction.openInDesktopApp(url: $0.url) }
        switch outcome {
        case .activated:
            return ActivationFeedback(title: "Opened", detail: "", recovery: [], dismissesPane: true)
        case .targetGone:
            return failure("That tab was closed", "\(item.title) is no longer open in \(location(of: item)).", [.refreshList, desktop, saved, .removeShortcut])
        case .targetChanged:
            return failure("That tab now shows something else", "Porter did not open it. The list has been refreshed.", [.refreshList])
        case .accountChanged:
            return failure("The account changed", "Porter will not open a chat from a different account. Check the list again.", [.refreshList])
        case .connectorOffline:
            let host = ProviderNames.host(for: item.provider)
            if host.isDesktopChatApp {
                return failure("\(host.displayName) is not open", "Open the \(host.displayName) app, then try again.", [.openHostApplication(host)])
            }
            return failure("\(host.displayName) is not connected", "Open \(host.displayName) with Porter\'s extension, then try again.", [.openHostApplication(host), desktop, saved])
        case .permissionDenied:
            return failure("Porter is not allowed to do that", "Check Porter's permissions in System Settings (Privacy & Security), or allow claude.ai in the extension options.", [.allowSiteAccess])
        case .unsupported:
            return failure("This can't be opened from here", "That destination does not support opening.", [desktop, saved])
        case .versionMismatch:
            return failure("Porter and its extension need updating", "They use different versions of the bridge.", [.openHostApplication(ProviderNames.host(for: item.provider))])
        case .timeout:
            return failure("No answer from Chrome", "It may have opened anyway. Check Chrome before trying again.", [.tryAgain, .refreshList])
        case .failed:
            return failure("Could not open it", "Something went wrong in the browser.", [.tryAgain, .refreshList])
        }
    }

    private static func location(of item: PanelItem) -> String {
        let host = ProviderNames.host(for: item.provider)
        if host.isDesktopChatApp { return "the \(host.displayName) app" }
        return host == .vscode ? "that VS Code window" : "its browser profile"
    }

    private static func failure(_ title: String, _ detail: String, _ actions: [RecoveryAction?]) -> ActivationFeedback {
        ActivationFeedback(title: title, detail: detail, recovery: actions.compactMap { $0 }, dismissesPane: false)
    }
}
