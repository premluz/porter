import Foundation

/// One status signal from a coding agent, reduced to the few fields Porter may keep. Hook input also
/// carries the user's prompt, tool arguments and a transcript path; none of those exist here, so
/// they cannot be stored, logged or sent by accident.
public struct AgentEvent: Codable, Sendable, Equatable {
    public static let claudeCodeSource = "claude-code"
    /// The environment value Claude Code sets for sessions started from its VS Code extension.
    public static let vscodeEntrypoint = "claude-vscode"

    public let source: String
    public let event: String
    public let sessionId: String
    public let cwd: String
    public let notificationType: String?
    public let entrypoint: String?

    public init(
        source: String = AgentEvent.claudeCodeSource, event: String, sessionId: String, cwd: String,
        notificationType: String? = nil, entrypoint: String? = nil
    ) {
        self.source = source
        self.event = event
        self.sessionId = sessionId
        self.cwd = cwd
        self.notificationType = notificationType
        self.entrypoint = entrypoint
    }
}

public enum AgentEventRejection: Error, Equatable, Sendable {
    case unsupportedSource(String)
    case unsupportedEvent(String)
    case invalidField(String)
}

/// What an event means for a session. Only documented Claude Code hook events appear here.
enum AgentTransition: Equatable {
    case set(activity: Activity, attention: Attention)
    case clear
    case ignore
}

extension AgentEvent {
    static let knownEvents: Set<String> = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Notification", "Stop", "SessionEnd",
    ]
    private static let maximumFieldLength = 64
    private static let tokenCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")

    public func validated() throws(AgentEventRejection) -> AgentEvent {
        guard source == Self.claudeCodeSource else { throw .unsupportedSource(source) }
        guard Self.knownEvents.contains(event) else { throw .unsupportedEvent(event) }
        guard BridgeValidation.isIdentifier(sessionId) else { throw .invalidField("sessionId") }
        guard BridgeValidation.isWorkspacePath(cwd) else { throw .invalidField("cwd") }
        for (name, value) in [("notificationType", notificationType), ("entrypoint", entrypoint)] {
            guard let value else { continue }
            guard (1...Self.maximumFieldLength).contains(value.count), value.unicodeScalars.allSatisfy(Self.tokenCharacters.contains) else {
                throw .invalidField(name)
            }
        }
        return self
    }

    /// A permission prompt or a question waits for the user; being idle at a prompt does not.
    var transition: AgentTransition {
        switch event {
        case "SessionStart", "Stop": .set(activity: .idle, attention: .none)
        case "UserPromptSubmit", "PreToolUse", "PostToolUse": .set(activity: .working, attention: .none)
        case "SessionEnd": .clear
        case "Notification": notificationTransition
        default: .ignore
        }
    }

    private var notificationTransition: AgentTransition {
        switch notificationType {
        case "permission_prompt", "elicitation_dialog", "agent_needs_input": .set(activity: .idle, attention: .needsUser)
        case "idle_prompt": .set(activity: .idle, attention: .none)
        default: .ignore
        }
    }
}
