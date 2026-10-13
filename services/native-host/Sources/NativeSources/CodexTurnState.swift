import Foundation
import ConversationCore
import OSLog

public struct CodexTurnReport: Equatable, Sendable {
    public let working: Bool
    public let end: TurnEnd?
}

/// Whether a Codex thread is in the middle of a turn, read from its session file without decoding any of it. Codex
/// writes a `task_started` record when a turn begins and `task_complete` or `turn_aborted` when it ends. Records are
/// found as raw byte sequences, because a single record can be megabytes (screenshots) and carries the conversation;
/// the markers are matched with their unescaped structural prefix, which text inside a message cannot contain because
/// its quotes are escaped.
enum CodexTurnState {
    /// A turn whose file has been silent this long is not claimed as working: a killed Codex leaves its last turn
    /// open for good, and a wrong "working" is worse than none. A long tool call that writes nothing for longer
    /// than this reads as not working until it writes again.
    static let silence: TimeInterval = 120
    /// How much of the end of the file is searched. A turn longer than this (with no marker inside) is not claimed.
    static let tailLimit = 16 * 1024 * 1024

    private static let prefix = #""type":"event_msg","payload":{"type":""#
    private static let started = Data((prefix + #"task_started""#).utf8)
    private static let ended: [(kind: TurnEndKind, marker: Data)] = [
        (.completed, Data((prefix + #"task_complete""#).utf8)),
        (.interrupted, Data((prefix + #"turn_aborted""#).utf8)),
    ]
    private static let timestampPrefix = Data(#"{"timestamp":""#.utf8)
    private static let newline: UInt8 = 10
    private static let quote: UInt8 = 34
    private static let logger = Logger(subsystem: "app.porter", category: "CodexTurnState")

    static func isOpen(atPath path: String, now: Date) -> Bool {
        do { return try report(atPath: path, now: now).working }
        catch {
            logger.error("Could not inspect Codex turn state: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func report(atPath path: String, now: Date) throws -> CodexTurnReport {
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let modified = attributes[.modificationDate] as? Date
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
        let tail = data.count > tailLimit ? data.suffix(tailLimit) : data[...]
        let lastStart = lastMarker(in: tail, marker: started)?.offset
        let endMarkers = ended.compactMap { kind, marker in
            lastMarker(in: tail, marker: marker).map { (kind, $0) }
        }
        let lastEnd = endMarkers.max { $0.1.offset < $1.1.offset }
        let end = lastEnd.map { kind, marker in TurnEnd(at: marker.at, kind: kind) }
        let recent = modified.map { now.timeIntervalSince($0) <= silence } ?? false
        let open = lastStart.map { start in lastEnd.map { start > $0.1.offset } ?? true } ?? false
        return CodexTurnReport(working: recent && open, end: end)
    }

    private static func lastMarker(in data: Data, marker: Data) -> (offset: Int, at: Date)? {
        var end = data.endIndex
        while let match = data.range(of: marker, options: .backwards, in: data.startIndex..<end) {
            if let at = timestamp(in: data, before: match.lowerBound) { return (match.lowerBound, at) }
            end = match.lowerBound
        }
        return nil
    }

    private static func timestamp(in data: Data, before marker: Int) -> Date? {
        let start = data[..<marker].lastIndex(of: newline).map { $0 + 1 } ?? data.startIndex
        let line = data[start..<marker]
        guard line.starts(with: timestampPrefix) else { return nil }
        let stampStart = start + timestampPrefix.count
        guard let stampEnd = data[stampStart..<marker].firstIndex(of: quote) else { return nil }
        let header = String(decoding: data[(stampEnd + 1)..<marker], as: UTF8.self)
        guard header.wholeMatch(of: /,(?:"ordinal":[0-9]+,)?/) != nil else { return nil }
        let stamp = String(decoding: data[stampStart..<stampEnd], as: UTF8.self)
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        if let date = try? fractional.parse(stamp) { return date }
        return try? Date.ISO8601FormatStyle().parse(stamp)
    }
}
