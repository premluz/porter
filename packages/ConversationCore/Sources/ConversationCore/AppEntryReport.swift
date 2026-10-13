import Foundation

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
    /// True when the connector has positive evidence that a turn is in progress right now. Absent means it has none,
    /// not that the conversation is idle.
    public let working: Bool?
    public let lastTurnEndedAt: Date?
    public let lastTurnEndKind: TurnEndKind?

    public init(
        provider: String, providerConversationId: String, title: String, bundleId: String, ordinal: Int,
        unread: Bool? = nil, lastActiveAt: Date? = nil, position: Int? = nil, workspacePath: String? = nil, working: Bool? = nil,
        lastTurnEndedAt: Date? = nil, lastTurnEndKind: TurnEndKind? = nil
    ) {
        self.working = working
        self.lastTurnEndedAt = lastTurnEndedAt
        self.lastTurnEndKind = lastTurnEndKind
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
