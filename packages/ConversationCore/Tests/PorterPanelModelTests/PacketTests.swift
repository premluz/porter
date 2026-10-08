import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("Context packets")
struct PacketTests {
    private static let fixtureRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().appending(path: "../../../contracts/fixtures").standardizedFileURL

    private func fixture(_ kind: String, _ name: String) throws -> Data {
        try Data(contentsOf: Self.fixtureRoot.appending(path: "\(kind)/context-packet/\(name).json"))
    }

    private func packet(_ name: String = "atlas-capture-with-memento-sources") throws -> ContextPacket {
        try ContextPacketDecoder.decode(fixture("valid", name))
    }

    @Test("every valid fixture decodes and every invalid one is refused")
    func sharedFixtures() throws {
        for kind in ["valid", "invalid"] {
            let directory = Self.fixtureRoot.appending(path: "\(kind)/context-packet")
            for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                let data = try Data(contentsOf: file)
                if kind == "valid" {
                    _ = try ContextPacketDecoder.decode(data)
                } else if (try? ContextPacketDecoder.decode(data)) != nil {
                    Issue.record("\(file.lastPathComponent) should be refused")
                }
            }
        }
    }

    @Test("oversized and unreadable input is refused before it is trusted")
    func hostileInput() {
        #expect(throws: PacketRejection.tooLarge(bytes: ContextPacketDecoder.maximumBytes + 1)) {
            try ContextPacketDecoder.decode(Data(repeating: 0x20, count: ContextPacketDecoder.maximumBytes + 1))
        }
        #expect(throws: PacketRejection.self) { try ContextPacketDecoder.decode(Data("{".utf8)) }
    }

    @Test("only current sources start included, and a stale one warns that it is left out")
    func defaultsToCurrent() throws {
        let review = PacketReview(packet: try packet())
        #expect(review.included == [0])
        #expect(review.warnings.contains { $0.contains("left out") })
    }

    @Test("including a stale source is allowed but warned about")
    func staleOptIn() throws {
        var review = PacketReview(packet: try packet())
        review.toggle(1)
        #expect(review.included == [0, 1])
        #expect(review.warnings.contains { $0.contains("out of date but included") })
        review.toggle(99)
        #expect(review.included == [0, 1])
    }

    @Test("the copied text shows title, instruction, task and each included source with its citation and revision")
    func rendersCitedText() throws {
        let text = try PacketReview(packet: try packet()).rendered()
        #expect(text.hasPrefix("Fix pane hit-testing"))
        #expect(text.contains("Instruction:\nMake clicks pass through transparent areas."))
        #expect(text.contains("Task: Fix pane hit-testing"))
        #expect(text.contains("[1] docs/UX_DESIGN.md lines 61-70 (Memento source 61228bfb"))
        #expect(text.contains("revision b637ea0a"))
        #expect(!text.contains("TASK-014 Native glass"))
    }

    @Test("a packet with nothing to say cannot be copied")
    func nothingToCopy() throws {
        var review = PacketReview(packet: try packet("minimal-no-destination"))
        #expect(throws: PacketReviewError.nothingToCopy) { try review.rendered() }
        review.toggle(0)
        #expect(review.included.isEmpty)
    }

    @Test("a packet whose included text is too long cannot be copied")
    func overLimit() throws {
        let original = try fixture("valid", "atlas-capture-with-memento-sources")
        guard var object = try JSONSerialization.jsonObject(with: original) as? [String: Any],
              var sources = object["sources"] as? [[String: Any]] else {
            Issue.record("fixture is not the expected shape")
            return
        }
        sources = (0..<5).map { index in
            var source = sources[0]
            source["citation"] = "source \(index)"
            source["excerpt"] = String(repeating: "y", count: 4_000)
            return source
        }
        object["sources"] = sources
        let big = try ContextPacketDecoder.decode(JSONSerialization.data(withJSONObject: object))
        let review = PacketReview(packet: big)
        #expect(review.isOverLimit)
        #expect(throws: PacketReviewError.overLimit(characters: review.characterCount, limit: PacketReview.maximumCharacters)) {
            try review.rendered()
        }
    }

    @Test("the destination is found among open chats, and several matches are all returned for the user to choose")
    func destinationCandidates() throws {
        let review = PacketReview(packet: try packet())
        let rows = [
            Fixture.row("fixture-chat-a", connector: Fixture.personal, alias: "Personal"),
            Fixture.row("fixture-chat-a", connector: Fixture.work, alias: "Work"),
            Fixture.row("other"),
        ]
        let items = Fixture.build(rows: rows, connectors: [Fixture.connector(), Fixture.connector(Fixture.work, alias: "Work")]).navigable
        #expect(review.destinationCandidates(in: items).count == 2)
        let none = Fixture.build(rows: [Fixture.row("other")]).navigable
        #expect(review.destinationCandidates(in: none).isEmpty)
        #expect(PacketReview(packet: try packet("minimal-no-destination")).destinationCandidates(in: items).isEmpty)
    }
}
