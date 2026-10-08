import Foundation

public enum SequenceVerdict: Equatable, Sendable {
    case accepted
    /// Already applied or older than the last applied event; drop it.
    case duplicate
    /// Belongs to a superseded connection; drop it and never replay it.
    case staleEpoch
    /// Events were lost. The event is applied, but the caller must request a snapshot
    /// and treat that connector's status as uncertain until it arrives.
    case gap(expected: Int, received: Int)
    /// No handshake has opened a stream for this connector.
    case unknownConnector
}

/// Orders bridge events per (connectorId, connectionEpoch). A new handshake starts a new epoch.
public struct EventSequencer: Sendable {
    private struct Stream: Sendable {
        let epoch: String
        var nextSequence: Int
    }

    private var streams: [String: Stream] = [:]

    public init() {}

    public mutating func begin(connectorId: String, epoch: String) {
        streams[connectorId] = Stream(epoch: epoch, nextSequence: 0)
    }

    public mutating func admit(connectorId: String, epoch: String, sequence: Int) -> SequenceVerdict {
        guard var stream = streams[connectorId] else { return .unknownConnector }
        guard stream.epoch == epoch else { return .staleEpoch }
        guard sequence >= stream.nextSequence else { return .duplicate }
        let expected = stream.nextSequence
        stream.nextSequence = sequence + 1
        streams[connectorId] = stream
        return sequence == expected ? .accepted : .gap(expected: expected, received: sequence)
    }
}
