import BridgeTransport
import ConversationCore
import Foundation
import PorterPanelModel
import PorterStore
import Testing
@testable import PorterMacKit

@MainActor
@Suite("Context packet review")
struct PacketFlowTests {
    private static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().appending(path: "../../../../packages/contracts/fixtures/valid/context-packet").standardizedFileURL

    private func fixtureURL(_ name: String) -> URL {
        Self.fixtures.appending(path: "\(name).json")
    }

    @Test("importing a valid packet starts a review with the destination chosen only when exactly one chat matches")
    func destinationAutoPick() async throws {
        let harness = try Harness(rows: [Harness.row("fixture-chat-a")])
        await harness.model.refresh()
        harness.model.importPacket(from: fixtureURL("atlas-capture-with-memento-sources"))
        #expect(harness.model.packetReview != nil)
        #expect(harness.model.packetDestination?.key.providerConversationId == "fixture-chat-a")
    }

    @Test("the same chat in two profiles is two candidates, so no destination is chosen for the user")
    func twoProfilesNoGuess() async throws {
        let personal = Harness.row("fixture-chat-a")
        let work = DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: "fixture-chat-a", provider: "claude",
            title: "Plan", profileAlias: "Personal", connectorId: "chrome-b", reachability: .connected, tabId: 1,
            windowId: 1, url: "https://claude.ai/chat/fixture-chat-a", routeCount: 1
        )
        let harness = try Harness(rows: [personal, work])
        await harness.model.refresh()
        harness.model.importPacket(from: fixtureURL("atlas-capture-with-memento-sources"))
        #expect(harness.model.packetDestination == nil)
        await harness.model.copyPacketAndOpen()
        #expect(harness.performer.copied.isEmpty)
        #expect(harness.source.activations.isEmpty)
    }

    @Test("a chat open in two tabs is found but not opened until the user picks a tab")
    func twoTabsRefused() async throws {
        let harness = try Harness(rows: [Harness.row("fixture-chat-a", tab: 1), Harness.row("fixture-chat-a", tab: 2)])
        await harness.model.refresh()
        harness.model.importPacket(from: fixtureURL("atlas-capture-with-memento-sources"))
        #expect(harness.model.packetDestination?.isAmbiguous == true)
        await harness.model.copyPacketAndOpen()
        #expect(harness.performer.copied.isEmpty)
        #expect(harness.source.activations.isEmpty)
        #expect(harness.model.problem?.contains("2 tabs") == true)
    }

    @Test("when the requested chat is not open there is no destination")
    func absentDestination() async throws {
        let absent = try Harness(rows: [Harness.row("something-else")])
        await absent.model.refresh()
        absent.model.importPacket(from: fixtureURL("atlas-capture-with-memento-sources"))
        #expect(absent.model.packetDestination == nil)
    }

    @Test("copy puts the reviewed text on the pasteboard and opens nothing")
    func copyOnly() async throws {
        let harness = try Harness(rows: [Harness.row("fixture-chat-a")])
        await harness.model.refresh()
        harness.model.importPacket(from: fixtureURL("atlas-capture-with-memento-sources"))
        harness.model.copyPacket()
        #expect(harness.performer.copied.count == 1)
        #expect(harness.performer.copied[0].contains("Fix pane hit-testing"))
        #expect(harness.source.activations.isEmpty)
    }

    @Test("copy and open copies first, then opens exactly the chosen chat")
    func copyAndOpen() async throws {
        let target = Harness.row("fixture-chat-a")
        let harness = try Harness(rows: [target, Harness.row("other", title: "Other")])
        await harness.model.refresh()
        harness.model.importPacket(from: fixtureURL("atlas-capture-with-memento-sources"))
        await harness.model.copyPacketAndOpen()
        #expect(harness.performer.copied.count == 1)
        #expect(harness.source.activations.map(\.0) == [target.destinationId])
    }

    @Test("copy and open without a chosen destination does nothing at all")
    func noDestinationNoCopy() async throws {
        let harness = try Harness(rows: [Harness.row("something-else")])
        await harness.model.refresh()
        harness.model.importPacket(from: fixtureURL("atlas-capture-with-memento-sources"))
        await harness.model.copyPacketAndOpen()
        #expect(harness.performer.copied.isEmpty)
        #expect(harness.source.activations.isEmpty)
        #expect(harness.model.problem != nil)
    }

    @Test("a source toggled off is not in the copied text")
    func toggledOff() async throws {
        let harness = try Harness(rows: [Harness.row("fixture-chat-a")])
        await harness.model.refresh()
        harness.model.importPacket(from: fixtureURL("atlas-capture-with-memento-sources"))
        harness.model.togglePacketSource(0)
        harness.model.copyPacket()
        #expect(!harness.performer.copied.contains { $0.contains("docs/UX_DESIGN.md") })
    }

    @Test("a refused file leaves no review open and explains why; ending review drops the packet")
    func refusedAndEnded() async throws {
        let harness = try Harness(rows: [])
        let bad = URL(fileURLWithPath: "/nonexistent/packet.json")
        harness.model.importPacket(from: bad)
        #expect(harness.model.packetReview == nil)
        #expect(harness.model.problem != nil)
        harness.model.importPacket(from: fixtureURL("minimal-no-destination"))
        #expect(harness.model.packetReview != nil)
        harness.model.endPacketReview()
        #expect(harness.model.packetReview == nil && harness.model.packetDestinationId == nil)
    }
}
