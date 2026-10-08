import Foundation

/// Record types other suite products own. Porter stores the reference, never the record (ADR-004).
public enum SuiteReferenceType: String, Codable, Sendable, CaseIterable {
    case porterConversation = "porter.conversation"
    case porterDestination = "porter.destination"
    case managerProject = "manager.project"
    case managerTask = "manager.task"
    case atlasCapture = "atlas.capture"
    case mementoProject = "memento.project"
    case mementoSource = "memento.source"
    case mementoEntry = "memento.entry"
}

/// Decoding rejects any reference contract this build does not understand.
public enum SuiteReferenceContract: String, Codable, Sendable {
    case v1 = "suite-ref/1"
}

/// Mirrors context-link.schema.json#/$defs/reference.
public struct SuiteReference: Codable, Sendable, Hashable {
    public let contract: SuiteReferenceContract
    public let type: SuiteReferenceType
    public let id: String
    public let workspaceId: String?
    public let revision: String?
    public let label: String?
}

public enum ContextRelation: String, Codable, Sendable {
    case relatesTo, capturedFor, citesSource
}

/// Only user-created links exist in v1; inferred links would need their own reviewed origin.
public enum ContextLinkOrigin: String, Codable, Sendable {
    case userLinked
}

/// Mirrors context-link.schema.json.
public struct ContextLink: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let from: SuiteReference
    public let to: SuiteReference
    public let relation: ContextRelation
    public let origin: ContextLinkOrigin
    public let createdAt: Date
}
