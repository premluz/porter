import ConversationCore
import Foundation
import NativeSources
import PorterPanelModel

/// What Porter knows about its sources right now. Plain values, so the checklist can be tested without a Mac's state.
public struct SetupInputs: Sendable, Equatable {
    /// Nil means the source is not attached at all (sample-data mode).
    public var chrome: SourceHealth?
    public var claudeApp: SourceHealth?
    public var chatgptApp: SourceHealth?
    /// Codex's own thread list, read from its local files; nil when Codex is not installed.
    public var codexThreads: SourceHealth?
    /// How many agents running in terminals have reported through their hooks; nil when that is not being watched.
    public var terminalAgents: Int?
    public var connectors: [ConnectorSummary]
    /// Names of VS Code-family editors installed on this Mac.
    public var installedEditors: [String]
    /// Whether Claude Code's settings contain Porter's hook; nil when that could not be read.
    public var claudeCodeHook: Bool?
    /// Which optional pieces this build carries, so a setup button is offered only when it can work.
    public var canInstallCompanion: Bool
    public var canEnableClaudeCodeStatus: Bool
    public var canSetUpChromeExtension: Bool
    public var launchAtLogin: LoginItemState
    /// Whether Porter may post a notice when a chat needs you; nil when there are no sources to notify about.
    public var notifications: NotificationState?

    public init(
        chrome: SourceHealth? = nil, claudeApp: SourceHealth? = nil, chatgptApp: SourceHealth? = nil, codexThreads: SourceHealth? = nil, terminalAgents: Int? = nil,
        connectors: [ConnectorSummary] = [], installedEditors: [String] = [], claudeCodeHook: Bool? = nil,
        canInstallCompanion: Bool = false, canEnableClaudeCodeStatus: Bool = false, canSetUpChromeExtension: Bool = false,
        launchAtLogin: LoginItemState = .notAvailable, notifications: NotificationState? = nil
    ) {
        self.launchAtLogin = launchAtLogin
        self.notifications = notifications
        self.canInstallCompanion = canInstallCompanion
        self.canEnableClaudeCodeStatus = canEnableClaudeCodeStatus
        self.canSetUpChromeExtension = canSetUpChromeExtension
        self.chrome = chrome
        self.claudeApp = claudeApp
        self.chatgptApp = chatgptApp
        self.codexThreads = codexThreads
        self.terminalAgents = terminalAgents
        self.connectors = connectors
        self.installedEditors = installedEditors
        self.claudeCodeHook = claudeCodeHook
    }
}

public enum SetupState: Sendable, Equatable {
    /// Working now.
    case ready
    /// Needs the user to do something.
    case needsAction
    /// Fine, but the app is not open, so there is nothing to read yet.
    case waiting
    /// Not set up, and Porter works without it.
    case optional
    case checking
}

public enum SetupAction: Sendable, Equatable {
    case openAutomationSettings
    case requestAccessibility
    case openApplication(HostApplication)
    case installEditorCompanion
    case enableClaudeCodeStatus
    case setUpChromeExtension
    case setLaunchAtLogin(Bool)
    case openLoginItemsSettings
    case requestNotifications
    case openNotificationSettings
}

public struct SetupRow: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    public let state: SetupState
    public let action: SetupAction?
    public let actionTitle: String?
    /// What this source reads, in plain words, so a permission is never a surprise.
    public let reads: String?
}

public struct SetupSection: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let rows: [SetupRow]
}

public enum SetupChecklist {
    public static func sections(for inputs: SetupInputs) -> [SetupSection] {
        let reads = [
            chromeRow(inputs.chrome), appRow(.claudeApp, id: "claudeApp", inputs.claudeApp), appRow(.chatgptApp, id: "chatgptApp", inputs.chatgptApp),
            codexRow(inputs.codexThreads),
        ]
            .compactMap { $0 }
        let extras = [extensionRow(inputs), editorsRow(inputs), hookRow(inputs), terminalRow(inputs), notificationsRow(inputs), loginRow(inputs)].compactMap { $0 }
        return [
            SetupSection(id: "sources", title: "Reads on its own", rows: reads),
            SetupSection(id: "extras", title: "Optional, adds detail", rows: extras),
        ].filter { !$0.rows.isEmpty }
    }

    /// How many of the sources that need nothing more than permission are ready, for a one-line summary.
    public static func summary(_ sections: [SetupSection]) -> String {
        let required = sections.first { $0.id == "sources" }?.rows ?? []
        let ready = required.filter { $0.state == .ready }.count
        let blocked = required.filter { $0.state == .needsAction }.count
        if required.isEmpty { return "Showing sample data" }
        if blocked > 0 { return "\(ready) of \(required.count) ready; \(blocked) need\(blocked == 1 ? "s" : "") your permission" }
        return ready == required.count ? "All ready" : "\(ready) of \(required.count) ready; the rest are not open"
    }

    private static func row(
        _ id: String, _ title: String, _ detail: String, _ state: SetupState,
        action: SetupAction? = nil, actionTitle: String? = nil
    ) -> SetupRow {
        SetupRow(id: id, title: title, detail: detail, state: state, action: action, actionTitle: actionTitle, reads: readsByRow[id])
    }

    /// Shown under each source. The same limits as docs/SECURITY_PRIVACY.md, in the words a person would use.
    static let readsByRow: [String: String] = [
        "chrome": "Reads the titles and addresses of your Claude and ChatGPT tabs. Not the pages. Incognito windows are skipped.",
        "claudeApp": "Reads the chat titles in the app's sidebar, in its left strip only. Not messages.",
        "chatgptApp": "Reads the chat titles in the app's sidebar, in its left strip only. Not messages.",
        "codexThreads": "Reads thread titles, last-update times and project folders from Codex's own list. Not messages.",
        "chromeExtension": "Reads the same tab titles and addresses, one profile at a time. Not the pages.",
        "editors": "Reads which Claude Code tabs are open in each window, by title and position. Not their contents.",
        "claudeCodeStatus": "Reads when an agent starts, asks something or finishes (session, folder and event name). Never your prompts or its answers.",
        "terminalAgents": "Reads the same start, ask and finish events from agents in terminals, and which terminal window they run in. Not what they print.",
        "notifications": "Posts a notice on this Mac when a chat needs you. Nothing is sent anywhere.",
    ]

    public static let privacyStatement = "Nothing leaves this Mac. Porter has no account, no server and no analytics."

    private static func chromeRow(_ health: SourceHealth?) -> SetupRow? {
        guard let health else { return nil }
        switch health {
        case .ready:
            return row("chrome", "Chrome", "Your Claude and ChatGPT tabs are listed. The profile shows as unknown without the extension.", .ready)
        case .unknown:
            return row("chrome", "Chrome", "Checking…", .checking)
        case .notRunning:
            return row("chrome", "Chrome", "Chrome is not open, so there is nothing to read yet.", .waiting, action: .openApplication(.chrome), actionTitle: "Open Chrome")
        case .permissionDenied:
            return row("chrome", "Chrome", "Porter is not allowed to control Chrome. Switch Porter on under Privacy & Security → Automation.", .needsAction, action: .openAutomationSettings, actionTitle: "Open Automation settings")
        case .failed(let reason):
            return row("chrome", "Chrome", "Chrome could not be read: \(reason)", .needsAction)
        }
    }

    private static func appRow(_ host: HostApplication, id: String, _ health: SourceHealth?) -> SetupRow? {
        guard let health else { return nil }
        let name = "\(host.displayName) app"
        switch health {
        case .ready:
            return row(id, name, "Its sidebar chats are listed.", .ready)
        case .unknown:
            return row(id, name, "Checking…", .checking)
        case .notRunning:
            return row(id, name, "The app is not open, so there is nothing to read yet.", .waiting, action: .openApplication(host), actionTitle: "Open \(host.displayName)")
        case .permissionDenied:
            return row(id, name, "Porter needs the Accessibility permission to read the app's sidebar. Switch Porter on under Privacy & Security → Accessibility, then restart Porter.", .needsAction, action: .requestAccessibility, actionTitle: "Allow Accessibility")
        case .failed(let reason):
            return row(id, name, reason.prefix(1).uppercased() + reason.dropFirst() + ".", .needsAction)
        }
    }

    private static func codexRow(_ health: SourceHealth?) -> SetupRow? {
        guard health == .ready else { return nil }
        return row(
            "codexThreads", "Codex threads",
            "Your recent Codex threads are listed under their project, from Codex's own thread list. They open in VS Code or the Codex app.", .ready
        )
    }

    private static func extensionRow(_ inputs: SetupInputs) -> SetupRow? {
        guard inputs.chrome != nil else { return nil }
        let connected = inputs.connectors.filter { $0.providerType == .chromeExtension && $0.reachability == .connected }
        if connected.isEmpty {
            return row(
                "chromeExtension", "Chrome extension", "Not connected. It adds profile names and exact tabs; Porter works without it.", .optional,
                action: inputs.canSetUpChromeExtension ? .setUpChromeExtension : nil, actionTitle: inputs.canSetUpChromeExtension ? "Set up…" : nil
            )
        }
        return row("chromeExtension", "Chrome extension", "\(connected.count) profile\(connected.count == 1 ? "" : "s") connected.", .ready)
    }

    /// The oldest companion this app is happy with. 0.2.0 added last-used times; a window still running 0.1.0 lists its
    /// chats with no time, which buries them below everything that has one.
    static let minimumCompanionVersion = [0, 2, 0]

    static func isOutdated(_ summary: ConnectorSummary) -> Bool {
        guard let declared = summary.adapterVersions["claude-code"] ?? summary.adapterVersions.values.first else { return true }
        let parts = declared.split(separator: ".").compactMap { Int($0) }
        return parts.lexicographicallyPrecedes(minimumCompanionVersion)
    }

    private static func editorsRow(_ inputs: SetupInputs) -> SetupRow? {
        let windows = inputs.connectors.filter { $0.providerType == .vscodeExtension && $0.reachability == .connected }
        if !windows.isEmpty {
            let outdated = windows.filter(isOutdated).count
            let count = "\(windows.count) window\(windows.count == 1 ? "" : "s") connected."
            guard outdated > 0 else { return row("editors", "VS Code companion", count, .ready) }
            let which = outdated == windows.count ? "All of them need" : "\(outdated) of them need"
            return row(
                "editors", "VS Code companion",
                "\(count) \(which) a reload to pick up the latest companion: in each window run Developer: Reload Window (⇧⌘P), or quit and reopen VS Code.",
                .needsAction
            )
        }
        guard !inputs.installedEditors.isEmpty else { return nil }
        let names = inputs.installedEditors.joined(separator: ", ")
        let detail = inputs.canInstallCompanion
            ? "Found \(names), but no window is connected. Install the companion, then reload the window."
            : "Found \(names), but no window is connected. Install the companion with extensions/vscode/scripts/package-vsix.sh, then reload the window."
        return row(
            "editors", "VS Code companion", detail, .optional,
            action: inputs.canInstallCompanion ? .installEditorCompanion : nil, actionTitle: inputs.canInstallCompanion ? "Install in \(names)" : nil
        )
    }

    private static func terminalRow(_ inputs: SetupInputs) -> SetupRow? {
        guard let count = inputs.terminalAgents else { return nil }
        if count > 0 {
            return row("terminalAgents", "Agents in terminals", "\(count) agent\(count == 1 ? "" : "s") in terminals listed, with their status. Terminal and iTerm tabs can be brought forward.", .ready)
        }
        return row("terminalAgents", "Agents in terminals", "None have reported yet. Turn on Claude Code status above, then start Claude Code in a terminal.", .optional)
    }

    private static func notificationsRow(_ inputs: SetupInputs) -> SetupRow? {
        switch inputs.notifications {
        case nil, .notAvailable?:
            return nil
        case .allowed?:
            return row("notifications", "Notifications", "Porter tells you on this Mac when a chat needs you.", .ready)
        case .notAsked?:
            return row("notifications", "Notifications", "Off. Allow them and Porter will tell you when a chat needs you.", .optional, action: .requestNotifications, actionTitle: "Allow notifications")
        case .denied?:
            return row("notifications", "Notifications", "Blocked in System Settings, so a chat that needs you is only shown in the pane.", .optional, action: .openNotificationSettings, actionTitle: "Open Notifications settings")
        }
    }

    private static func loginRow(_ inputs: SetupInputs) -> SetupRow? {
        switch inputs.launchAtLogin {
        case .notAvailable:
            return nil
        case .on:
            return row("launchAtLogin", "Open at login", "Porter starts when you log in.", .ready, action: .setLaunchAtLogin(false), actionTitle: "Turn off")
        case .off:
            return row("launchAtLogin", "Open at login", "Porter starts only when you open it.", .optional, action: .setLaunchAtLogin(true), actionTitle: "Turn on")
        case .needsApproval:
            return row("launchAtLogin", "Open at login", "macOS needs you to switch Porter on under System Settings → General → Login Items.", .needsAction, action: .openLoginItemsSettings, actionTitle: "Open Login Items")
        }
    }

    private static func hookRow(_ inputs: SetupInputs) -> SetupRow? {
        guard let installed = inputs.claudeCodeHook, inputs.chrome != nil || !inputs.installedEditors.isEmpty else { return nil }
        return installed
            ? row("claudeCodeStatus", "Claude Code status", "Working and Needs you are shown on Claude Code tabs.", .ready)
            : row(
                "claudeCodeStatus", "Claude Code status",
                inputs.canEnableClaudeCodeStatus
                    ? "Not set up. Turning it on adds Porter's hooks to Claude Code's settings (a backup is made first) and shows Working and Needs you."
                    : "Not set up. Run services/native-host/scripts/claude-hooks.sh --apply to show Working and Needs you.",
                .optional, action: inputs.canEnableClaudeCodeStatus ? .enableClaudeCodeStatus : nil,
                actionTitle: inputs.canEnableClaudeCodeStatus ? "Turn on…" : nil
            )
    }
}
