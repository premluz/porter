import Foundation

/// Mirrors packages/contracts/schemas/conversation.schema.json.
public struct Conversation: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let provider: String
    public let providerConversationId: String?
    public let accountScopeId: UUID?
    public let workspaceScopeId: String?
    public let title: String
    public let createdAt: Date
    public let lastObservedAt: Date
    public let revision: Int
}

public enum AccountEvidence: String, Codable, Sendable {
    case providerReported, userLabel, unknown
}

/// Mirrors account-scope.schema.json. A user label names an account for display; it never verifies one.
public struct AccountScope: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let provider: String
    public let evidence: AccountEvidence
    public let opaqueProviderAccountId: String?
    public let displayLabel: String?
    public let verifiedAt: Date?

    public var verifiedAccountId: String? {
        guard evidence == .providerReported, verifiedAt != nil else { return nil }
        return opaqueProviderAccountId
    }
}

public enum ConnectorType: String, Codable, Sendable {
    case chromeExtension, safariExtension, vscodeExtension
}

/// Mirrors connector.schema.json. One per browser profile installation.
public struct Connector: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let deviceId: UUID
    public let providerType: ConnectorType
    public let profileAlias: String?
    public let installationId: UUID
    public let connectionEpoch: String
    public let protocolVersion: String
    public let adapterVersions: [String: String]
    public let connectedAt: Date
    public let lastHeartbeatAt: Date
}

/// Mirrors status-observation.schema.json.
public struct StatusObservation: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let destinationId: UUID
    public let activity: Activity
    public let attention: Attention
    public let evidenceKind: EvidenceKind
    public let observedAt: Date
    public let receivedAt: Date
    public let expiresAt: Date
    public let sequence: Int
    public let connectionEpoch: String
    public let adapterVersion: String

    public init(
        id: UUID, destinationId: UUID, activity: Activity, attention: Attention, evidenceKind: EvidenceKind,
        observedAt: Date, receivedAt: Date, expiresAt: Date, sequence: Int, connectionEpoch: String, adapterVersion: String
    ) {
        self.id = id
        self.destinationId = destinationId
        self.activity = activity
        self.attention = attention
        self.evidenceKind = evidenceKind
        self.observedAt = observedAt
        self.receivedAt = receivedAt
        self.expiresAt = expiresAt
        self.sequence = sequence
        self.connectionEpoch = connectionEpoch
        self.adapterVersion = adapterVersion
    }
}

public enum ActivationOutcome: String, Codable, Sendable {
    case activated, targetGone, targetChanged, accountChanged, connectorOffline
    case permissionDenied, unsupported, versionMismatch, timeout, failed
}

/// Mirrors activation-result.schema.json.
public struct ActivationResult: Codable, Sendable, Equatable {
    public let requestId: UUID
    public let destinationId: UUID
    public let destinationRevision: Int
    public let outcome: ActivationOutcome

    public init(requestId: UUID, destinationId: UUID, destinationRevision: Int, outcome: ActivationOutcome) {
        self.requestId = requestId
        self.destinationId = destinationId
        self.destinationRevision = destinationRevision
        self.outcome = outcome
    }
}
