import ConversationCore
import Foundation
import PorterPanelModel
import Testing
@testable import PorterMacKit

@MainActor
@Suite("The docked tab's one mark for all the chats together")
struct TabStatusTests {
    private func status(_ display: DisplayStatus, for row: DestinationRow, freshness: Freshness = .fresh) -> DestinationStatus {
        let now = Date(timeIntervalSince1970: 1_791_450_000)
        let observation = StatusObservation(
            id: UUID(), destinationId: row.destinationId, activity: .idle, attention: .needsUser, evidenceKind: .providerEvent,
            observedAt: now, receivedAt: now, expiresAt: now.addingTimeInterval(1_800), sequence: 1, connectionEpoch: "hook", adapterVersion: "0.1.0"
        )
        return DestinationStatus(display: display, freshness: freshness, reachability: .connected, lastKnown: observation)
    }

    private func shown(_ states: [(DisplayStatus, Freshness)]) async throws -> ItemStatus? {
        let rows = states.indices.map { Harness.row("chat-\($0)", title: "Chat \($0)", tab: $0 + 1) }
        let harness = try Harness(rows: rows)
        for (row, state) in zip(rows, states) { harness.source.statusMap[row.destinationId] = status(state.0, for: row, freshness: state.1) }
        await harness.model.refresh()
        return harness.model.tabStatus
    }

    @Test("a question outranks work in progress, which outranks nothing, whatever order the chats are in")
    func priority() async throws {
        #expect(try await shown([(.working, .fresh), (.needsUser, .fresh), (.idle, .fresh)])?.display == .needsUser)
        #expect(try await shown([(.idle, .fresh), (.working, .fresh), (.idle, .fresh)])?.display == .working)
        #expect(try await shown([(.idle, .fresh), (.idle, .fresh)]) == nil)
        #expect(try await shown([]) == nil)
    }

    @Test("a question or work that has gone stale is not claimed")
    func stale() async throws {
        #expect(try await shown([(.needsUser, .stale), (.working, .stale)]) == nil)
        #expect(try await shown([(.needsUser, .stale), (.working, .fresh)])?.display == .working)
    }
}
