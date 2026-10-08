import ConversationCore
import Foundation

public enum HookInputError: Error, Equatable, Sendable {
    case notAnObject
    case missing(String)
}

/// Reduces what Claude Code hands a hook to the few fields Porter may keep. The input also holds the
/// user's prompt, tool arguments and a transcript path; this is the one place they are read past, and
/// nothing outside the whitelist is ever copied, logged or returned, including in errors.
public enum HookInput {
    public static let maximumBytes = 1_048_576

    public static func parse(_ data: Data, entrypoint: String?) throws(HookInputError) -> AgentEvent {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw .notAnObject }
        func text(_ key: String) -> String? { object[key] as? String }
        guard let event = text("hook_event_name") else { throw .missing("hook_event_name") }
        guard let session = text("session_id") else { throw .missing("session_id") }
        guard let cwd = text("cwd") else { throw .missing("cwd") }
        return AgentEvent(
            event: event, sessionId: session, cwd: cwd, notificationType: text("notification_type"), entrypoint: entrypoint
        )
    }
}
