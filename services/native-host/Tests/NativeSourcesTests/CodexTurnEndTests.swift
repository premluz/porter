import ConversationCore
import Foundation
import Testing
@testable import NativeSources

@Suite("Codex end-marker timestamps")
struct CodexTurnEndTests {
    private let stamp = "2026-10-10T11:18:03.029Z"

    private func inspect(_ lines: [String]) throws -> CodexTurnReport {
        let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("porter-turn-end-\(UUID()).jsonl")
        try Data(lines.joined(separator: "\n").utf8).write(to: file)
        let report: CodexTurnReport
        do { report = try CodexTurnState.report(atPath: file.path, now: Date()) }
        catch {
            try FileManager.default.removeItem(at: file)
            throw error
        }
        try FileManager.default.removeItem(at: file)
        return report
    }

    private func marker(_ type: String, stamp: String, ordinal: Bool = true) -> String {
        let order = ordinal ? #""ordinal":17,"# : ""
        return #"{"timestamp":"\#(stamp)",\#(order)"type":"event_msg","payload":{"type":"\#(type)","turn_id":"t"}}"#
    }

    @Test(arguments: [("task_complete", TurnEndKind.completed), ("turn_aborted", .interrupted)])
    func exactMarkerTime(type: String, kind: TurnEndKind) throws {
        let report = try inspect([marker(type, stamp: stamp)])
        let date = try Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(stamp)
        #expect(report.end == TurnEnd(at: date, kind: kind))
        #expect(!report.working)
    }

    @Test func secondShapeAndLatestMarker() throws {
        let plain = "2026-10-10T11:20:00Z"
        let report = try inspect([marker("task_complete", stamp: stamp), marker("turn_aborted", stamp: plain, ordinal: false)])
        #expect(report.end?.at == (try Date.ISO8601FormatStyle().parse(plain)))
        #expect(report.end?.kind == .interrupted)
    }

    @Test func quotedMarkersAndInvalidTimeCannotEndTurn() throws {
        let quote = #"{"timestamp":"2026-10-10T11:20:00Z","type":"response_item","payload":{"text":"\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\""}}"#
        #expect(try inspect([marker("task_started", stamp: stamp), quote]).end == nil)
        #expect(try inspect([marker("task_complete", stamp: "invalid")]).end == nil)
    }

    @Test func nestedEventObjectIsNotATopLevelBoundary() throws {
        let nested = #"{"timestamp":"2026-10-10T11:20:00Z","type":"response_item","payload":{"object":{"type":"event_msg","payload":{"type":"task_complete"}}}}"#
        let report = try inspect([marker("task_started", stamp: stamp), nested])
        #expect(report.working && report.end == nil)
    }
}
