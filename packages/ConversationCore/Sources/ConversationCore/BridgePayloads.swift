import Foundation

/// Mirrors packages/contracts/schemas/bridge-payload.schema.json.
public enum BridgeLimits {
    public static let maximumTabsPerSnapshot = 200
    public static let maximumTitleLength = 512
    public static let maximumIdentifierLength = 128
    public static let maximumLabelLength = 120
    public static let maximumAdapterCount = 16
}

/// A tab the connector's adapter recognizes as a supported conversation. Never general browsing.
public struct TabReport: Codable, Sendable, Equatable {
    public let tabId: Int
    public let windowId: Int
    public let provider: String
    public let providerConversationId: String
    public let title: String
    public let canonicalUrl: String
    /// When the tab last became the visible one, as the browser reports it. Used only to order the list.
    public let lastActiveAt: Date?

    public init(
        tabId: Int, windowId: Int, provider: String, providerConversationId: String,
        title: String, canonicalUrl: String, lastActiveAt: Date? = nil
    ) {
        self.tabId = tabId
        self.windowId = windowId
        self.provider = provider
        self.providerConversationId = providerConversationId
        self.title = title
        self.canonicalUrl = canonicalUrl
        self.lastActiveAt = lastActiveAt
    }
}

public enum ConnectorKind: String, Codable, Sendable {
    /// `chrome` is the browser extension; `chromeScripting` is Porter reading Chrome itself, with no extension.
    case chrome, vscode, chromeScripting
    /// Desktop chat apps (Claude, ChatGPT) read through Accessibility.
    case desktopApp

    /// The prefix that makes a connector ID readable and ties it to its kind.
    var idPrefix: String { rawValue }

    var connectorType: ConnectorType {
        switch self {
        case .chrome: .chromeExtension
        case .vscode: .vscodeExtension
        case .chromeScripting: .chromeScripting
        case .desktopApp: .desktopApp
        }
    }
}

public struct HelloPayload: Codable, Sendable, Equatable {
    public let installationId: UUID
    public let profileAlias: String?
    /// Absent means a browser extension, which keeps older connectors working unchanged.
    public let connectorKind: ConnectorKind?
    public let adapterVersions: [String: String]

    public init(
        installationId: UUID, profileAlias: String?, connectorKind: ConnectorKind? = nil, adapterVersions: [String: String]
    ) {
        self.installationId = installationId
        self.profileAlias = profileAlias
        self.connectorKind = connectorKind
        self.adapterVersions = adapterVersions
    }

    public var kind: ConnectorKind { connectorKind ?? .chrome }
}

public struct HelloAckPayload: Codable, Sendable, Equatable {
    public let accepted: Bool
    public let connectorId: String?

    public init(accepted: Bool, connectorId: String?) {
        self.accepted = accepted
        self.connectorId = connectorId
    }
}

/// A Claude Code tab in an editor window. There is no stable tab ID in an editor, so identity is the
/// provider conversation ID the connector derives, and position is only where to find it now.
public struct EditorTabReport: Codable, Sendable, Equatable {
    public let provider: String
    public let providerConversationId: String
    public let title: String
    public let workspacePath: String
    public let viewColumn: Int
    public let index: Int
    public let lastActiveAt: Date?

    public init(
        provider: String, providerConversationId: String, title: String,
        workspacePath: String, viewColumn: Int, index: Int, lastActiveAt: Date? = nil
    ) {
        self.provider = provider
        self.providerConversationId = providerConversationId
        self.title = title
        self.workspacePath = workspacePath
        self.viewColumn = viewColumn
        self.index = index
        self.lastActiveAt = lastActiveAt
    }
}

/// A conversation listed in a desktop chat app's sidebar. The app gives no identifier, so identity is
/// the title plus its position among entries with the same title: a rename, or a duplicate that moves,
/// looks like a different conversation. `providerConversationId` is derived by the connector from both.
public struct AppEntryReport: Codable, Sendable, Equatable {
    public let provider: String
    public let providerConversationId: String
    public let title: String
    public let bundleId: String
    public let ordinal: Int
    /// The app's own "unread" marker, when it shows one. Absent means the app shows none, not "read".
    public let unread: Bool?
    public let lastActiveAt: Date?
    /// Where the app lists it, 0 first. Apps list newest first, so this orders entries when no time is known.
    public let position: Int?
    /// The project folder the conversation belongs to, when the app records one. A VS Code thread is opened in the
    /// window of that folder, so the window is brought forward first.
    public let workspacePath: String?

    public init(
        provider: String, providerConversationId: String, title: String, bundleId: String, ordinal: Int,
        unread: Bool? = nil, lastActiveAt: Date? = nil, position: Int? = nil, workspacePath: String? = nil
    ) {
        self.workspacePath = workspacePath
        self.position = position
        self.provider = provider
        self.providerConversationId = providerConversationId
        self.title = title
        self.bundleId = bundleId
        self.ordinal = ordinal
        self.unread = unread
        self.lastActiveAt = lastActiveAt
    }
}

public struct InventorySnapshotPayload: Codable, Sendable, Equatable {
    public let tabs: [TabReport]
    public let editorTabs: [EditorTabReport]?
    public let appEntries: [AppEntryReport]?

    public init(tabs: [TabReport], editorTabs: [EditorTabReport]? = nil, appEntries: [AppEntryReport]? = nil) {
        self.tabs = tabs
        self.editorTabs = editorTabs
        self.appEntries = appEntries
    }
}

public struct DestinationUpsertPayload: Codable, Sendable, Equatable {
    public let tab: TabReport

    public init(tab: TabReport) { self.tab = tab }
}

public struct DestinationRemovePayload: Codable, Sendable, Equatable {
    public let tabId: Int

    public init(tabId: Int) { self.tabId = tabId }
}

/// Where to find an editor tab, and the title it must still have for the connector to act.
public struct EditorTarget: Codable, Sendable, Equatable {
    public let workspacePath: String
    public let viewColumn: Int
    public let index: Int
    public let expectedTitle: String
}

/// Which sidebar entry of a desktop app to open, and the title it must still have for the connector to act.
public struct AppTarget: Codable, Sendable, Equatable {
    public let bundleId: String
    public let expectedTitle: String
    public let ordinal: Int
}

/// The registry's only navigation command. The connector re-verifies the target before acting.
/// A browser target carries tabId and windowId; an editor target carries `editor`.
public struct ActivateRequestPayload: Codable, Sendable, Equatable {
    public let requestId: UUID
    public let destinationId: UUID
    public let destinationRevision: Int
    public let tabId: Int?
    public let windowId: Int?
    public let expectedProvider: String
    public let expectedConversationId: String
    public let editor: EditorTarget?
    public let app: AppTarget?
}

public enum BridgeErrorCode: String, Codable, Sendable {
    case malformed, unsupportedVersion, unauthorized, duplicateInstallation, outOfOrder, `internal`
}

public struct BridgeErrorPayload: Codable, Sendable, Equatable {
    public let code: BridgeErrorCode
    public let message: String

    public init(code: BridgeErrorCode, message: String) {
        self.code = code
        self.message = message
    }
}

struct EmptyPayload: Codable, Sendable, Equatable {}
