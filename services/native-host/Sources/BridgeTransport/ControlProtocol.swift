import ConversationCore
import Foundation

/// Stand-in for the Mac pane until it exists: the same operations the pane will perform.
public struct ControlRequest: Codable, Sendable, Equatable {
    public enum Command: String, Codable, Sendable { case list, activate, agentEvent }

    public let command: Command
    public let destinationId: UUID?
    public let revision: Int?
    /// A status signal from a coding agent's hook; only the whitelisted fields of AgentEvent exist.
    public let agent: AgentEvent?

    public init(command: Command, destinationId: UUID? = nil, revision: Int? = nil, agent: AgentEvent? = nil) {
        self.command = command
        self.destinationId = destinationId
        self.revision = revision
        self.agent = agent
    }
}

public struct ControlResponse: Codable, Sendable, Equatable {
    public let ok: Bool
    public let error: String?
    public let connectors: [ConnectorSummary]?
    public let rows: [DestinationRow]?
    public let outcome: ActivationOutcome?
    /// Whether the Chrome application itself was asked to come forward, separately from the tab.
    public let appActivation: String?

    public static func failure(_ message: String) -> ControlResponse {
        ControlResponse(ok: false, error: message, connectors: nil, rows: nil, outcome: nil, appActivation: nil)
    }

    public static func accepted() -> ControlResponse {
        ControlResponse(ok: true, error: nil, connectors: nil, rows: nil, outcome: nil, appActivation: nil)
    }

    public static func listing(_ connectors: [ConnectorSummary], _ rows: [DestinationRow]) -> ControlResponse {
        ControlResponse(ok: true, error: nil, connectors: connectors, rows: rows, outcome: nil, appActivation: nil)
    }

    public static func activation(_ outcome: ActivationOutcome, appActivation: String?) -> ControlResponse {
        ControlResponse(ok: true, error: nil, connectors: nil, rows: nil, outcome: outcome, appActivation: appActivation)
    }
}

public enum ControlLimits {
    public static let maximumRequestBytes = 4 * 1024
    public static let maximumResponseBytes = 4 * 1024 * 1024
}
