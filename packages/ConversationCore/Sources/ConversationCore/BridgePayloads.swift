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

    public init(
        tabId: Int, windowId: Int, provider: String, providerConversationId: String,
        title: String, canonicalUrl: String
    ) {
        self.tabId = tabId
        self.windowId = windowId
        self.provider = provider
        self.providerConversationId = providerConversationId
        self.title = title
        self.canonicalUrl = canonicalUrl
    }
}

public struct HelloPayload: Codable, Sendable, Equatable {
    public let installationId: UUID
    public let profileAlias: String?
    public let adapterVersions: [String: String]

    public init(installationId: UUID, profileAlias: String?, adapterVersions: [String: String]) {
        self.installationId = installationId
        self.profileAlias = profileAlias
        self.adapterVersions = adapterVersions
    }
}

public struct HelloAckPayload: Codable, Sendable, Equatable {
    public let accepted: Bool
    public let connectorId: String?

    public init(accepted: Bool, connectorId: String?) {
        self.accepted = accepted
        self.connectorId = connectorId
    }
}

public struct InventorySnapshotPayload: Codable, Sendable, Equatable {
    public let tabs: [TabReport]

    public init(tabs: [TabReport]) { self.tabs = tabs }
}

public struct DestinationUpsertPayload: Codable, Sendable, Equatable {
    public let tab: TabReport

    public init(tab: TabReport) { self.tab = tab }
}

public struct DestinationRemovePayload: Codable, Sendable, Equatable {
    public let tabId: Int

    public init(tabId: Int) { self.tabId = tabId }
}

/// The registry's only navigation command. The connector re-verifies the target before acting.
public struct ActivateRequestPayload: Codable, Sendable, Equatable {
    public let requestId: UUID
    public let destinationId: UUID
    public let destinationRevision: Int
    public let tabId: Int
    public let windowId: Int
    public let expectedProvider: String
    public let expectedConversationId: String
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
