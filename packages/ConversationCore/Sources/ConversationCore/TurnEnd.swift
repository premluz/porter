import Foundation

public enum TurnEndKind: String, Codable, Sendable {
    case completed, interrupted
}

/// Structural end evidence, independent of whether current activity is still observable.
public struct TurnEnd: Codable, Equatable, Sendable {
    public let at: Date
    public let kind: TurnEndKind

    public init(at: Date, kind: TurnEndKind) {
        self.at = at
        self.kind = kind
    }
}
