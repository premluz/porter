import Foundation

/// Conversation activity only. Project-task progress is owned by Manager and never modelled here.
public enum Activity: String, Codable, Sendable, CaseIterable {
    case working, idle, unknown
}

public enum Attention: String, Codable, Sendable, CaseIterable {
    case needsUser, newResponse, none, unknown
}

public enum Reachability: String, Codable, Sendable, CaseIterable {
    case connected, disconnected, unavailable
}

public enum Freshness: String, Codable, Sendable, CaseIterable {
    case fresh, stale, unknown
}

public enum EvidenceKind: String, Codable, Sendable, CaseIterable {
    case providerEvent, domSignal, userAcknowledged, none
}

/// The single label a row shows. Case order is display precedence for fresh observations.
public enum DisplayStatus: String, Sendable, CaseIterable, Comparable {
    case needsUser, working, newResponse, idle, unknown

    private var rank: Int { Self.allCases.firstIndex(of: self) ?? Self.allCases.count }

    public static func < (lhs: DisplayStatus, rhs: DisplayStatus) -> Bool {
        lhs.rank < rhs.rank
    }
}
