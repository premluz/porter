import Foundation

public enum CapabilityName: String, Codable, Sendable {
    case discover, observeStatus, activate, openMobile, readPreview, draft, send
}

/// Capability support is per destination and adapter version, never a provider-wide promise.
public struct Capability: Codable, Sendable, Equatable {
    public let name: CapabilityName
    public let supported: Bool
    public let reason: String?
}

public enum DestinationKind: String, Codable, Sendable {
    case browserTab, desktopLink, mobileLink, editorTab, appEntry
}

/// Mirrors destination.schema.json. The locator's kind is the destination kind.
public struct Destination: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let conversationId: UUID
    public let deviceId: UUID
    public let connectorId: String?
    public let identityEpoch: String
    public let locator: Locator
    public let capabilities: [Capability]
    public let lastVerifiedAt: Date
    public let revision: Int

    public var kind: DestinationKind { locator.kind }

    public func supports(_ name: CapabilityName) -> Bool {
        capabilities.contains { $0.name == name && $0.supported }
    }
}

public struct BrowserTabLocator: Codable, Sendable, Equatable {
    public let connectorId: String
    public let connectionEpoch: String
    public let tabId: Int
    public let windowIdHint: Int?
    public let canonicalUrl: String?
}

public struct DesktopLinkLocator: Codable, Sendable, Equatable {
    public let bundleId: String
    public let deepLink: String
    public let accountScopeId: UUID?
}

public struct MobileLinkLocator: Codable, Sendable, Equatable {
    public let url: String
    public let accountRequirement: String?
}

/// A tab inside a desktop editor window. The window is found by its workspace folder, then the tab by
/// position; neither is a stable ID, so the connector re-checks the title before acting.
public struct EditorTabLocator: Codable, Sendable, Equatable {
    public let bundleId: String
    public let workspacePath: String
    public let viewColumn: Int
    public let index: Int

    public init(bundleId: String, workspacePath: String, viewColumn: Int, index: Int) {
        self.bundleId = bundleId
        self.workspacePath = workspacePath
        self.viewColumn = viewColumn
        self.index = index
    }
}

/// An entry in a desktop chat app's sidebar, found again by title and position and re-checked before use.
public struct AppEntryLocator: Codable, Sendable, Equatable {
    public let bundleId: String
    public let title: String
    public let ordinal: Int
    public let workspacePath: String?

    public init(bundleId: String, title: String, ordinal: Int, workspacePath: String? = nil) {
        self.bundleId = bundleId
        self.title = title
        self.ordinal = ordinal
        self.workspacePath = workspacePath
    }
}

/// Encoded flat with a `kind` discriminator, matching the schema's oneOf branches.
public enum Locator: Codable, Sendable, Equatable {
    case browserTab(BrowserTabLocator)
    case desktopLink(DesktopLinkLocator)
    case mobileLink(MobileLinkLocator)
    case editorTab(EditorTabLocator)
    case appEntry(AppEntryLocator)

    private enum CodingKeys: String, CodingKey { case kind }

    public var kind: DestinationKind {
        switch self {
        case .browserTab: .browserTab
        case .desktopLink: .desktopLink
        case .mobileLink: .mobileLink
        case .editorTab: .editorTab
        case .appEntry: .appEntry
        }
    }

    public init(from decoder: any Decoder) throws {
        let kind = try decoder.container(keyedBy: CodingKeys.self).decode(DestinationKind.self, forKey: .kind)
        switch kind {
        case .browserTab: self = .browserTab(try BrowserTabLocator(from: decoder))
        case .desktopLink: self = .desktopLink(try DesktopLinkLocator(from: decoder))
        case .mobileLink: self = .mobileLink(try MobileLinkLocator(from: decoder))
        case .editorTab: self = .editorTab(try EditorTabLocator(from: decoder))
        case .appEntry: self = .appEntry(try AppEntryLocator(from: decoder))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .browserTab(let value): try value.encode(to: encoder)
        case .desktopLink(let value): try value.encode(to: encoder)
        case .mobileLink(let value): try value.encode(to: encoder)
        case .editorTab(let value): try value.encode(to: encoder)
        case .appEntry(let value): try value.encode(to: encoder)
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
    }
}
