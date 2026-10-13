import Foundation

struct AgentSession: Sendable, Equatable {
    let cwd: String
    let entrypoint: String?
    let activity: Activity
    let attention: Attention
    let receivedAt: Date
    let sequence: Int
    let tty: String?
    let hostApp: String?
    let turnEnd: TurnEnd?
}

/// An agent running in a terminal, as its hook events show it.
public struct TerminalSession: Sendable, Equatable {
    public let sessionId: String
    public let cwd: String
    public let tty: String
    public let hostApp: String
    public let activity: Activity
    public let attention: Attention
    public let receivedAt: Date

    public init(sessionId: String, cwd: String, tty: String, hostApp: String, activity: Activity, attention: Attention, receivedAt: Date) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.tty = tty
        self.hostApp = hostApp
        self.activity = activity
        self.attention = attention
        self.receivedAt = receivedAt
    }
}

/// Which tab a session belongs to, kept by the tab's connector-derived conversation id (not the registry's route id,
/// which is new every run), so it survives Porter restarting. The tab in front when the prompt was submitted.
public struct AgentBinding: Codable, Sendable, Equatable {
    public let conversationId: String
    public let workspace: String
    public let boundAt: Date

    public init(conversationId: String, workspace: String, boundAt: Date) {
        self.conversationId = conversationId
        self.workspace = workspace
        self.boundAt = boundAt
    }
}

/// What the registry knows about one agent session, for diagnosing a status that does not show.
public struct AgentSessionSummary: Codable, Sendable, Equatable {
    public let shortId: String
    public let folder: String
    public let activity: String
    public let ageSeconds: Int
    /// The title of the tab it is bound to, or nil when it is not bound to one.
    public let boundTitle: String?
}
