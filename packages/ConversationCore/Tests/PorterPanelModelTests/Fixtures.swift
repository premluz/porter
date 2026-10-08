import ConversationCore
import Foundation
import PorterStore
@testable import PorterPanelModel

enum Fixture {
    static let now = Date(timeIntervalSince1970: 1_791_450_000)
    static let personal = "chrome-personal"
    static let work = "chrome-work"

    static func row(
        _ chat: String, title: String = "Plan", connector: String = personal, alias: String = "Personal",
        tab: Int = 1, reachability: Reachability = .connected
    ) -> DestinationRow {
        DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: chat, provider: "claude",
            title: title, profileAlias: alias, connectorId: connector, reachability: reachability,
            tabId: tab, windowId: 1, url: "https://claude.ai/chat/\(chat)", routeCount: 1
        )
    }

    static func connector(_ id: String = personal, alias: String = "Personal", up: Bool = true) -> ConnectorSummary {
        ConnectorSummary(connectorId: id, profileAlias: alias, reachability: up ? .connected : .disconnected, routeCount: 0)
    }

    static func key(_ chat: String, connector: String = personal) -> ConversationKey {
        // Fixture keys are valid by construction; a failure here is a broken fixture, not a runtime case.
        guard let key = try? ConversationKey(provider: "claude", connectorId: connector, providerConversationId: chat) else {
            preconditionFailure("invalid fixture key \(chat)")
        }
        return key
    }

    static func record(
        _ chat: String, connector: String = personal, title: String = "Pinned plan", pinned: Bool = true,
        order: Int = 0, hidden: Bool = false
    ) -> PreferenceRecord {
        PreferenceRecord(
            key: key(chat, connector: connector), title: title, canonicalUrl: "https://claude.ai/chat/\(chat)",
            profileAlias: "Personal", pinned: pinned, pinOrder: order, hidden: hidden, revision: 1,
            modifiedAt: now, modifiedByDevice: UUID()
        )
    }

    static func build(
        rows: [DestinationRow] = [], connectors: [ConnectorSummary] = [connector()], records: [PreferenceRecord] = [],
        query: String = "", showHidden: Bool = false, frozen: [String]? = nil, statuses: [UUID: DestinationStatus] = [:]
    ) -> PanelSnapshot {
        PanelBuilder.build(PanelInputs(
            rows: rows, connectors: connectors, records: records, statuses: statuses, query: query,
            showHidden: showHidden, frozenOrder: frozen, now: now
        ))
    }
}

/// Observations for status tests; mirrors the helper used by the core tests.
enum Sample {
    static func observation(
        destinationId: UUID, activity: Activity, attention: Attention = .none, receivedAt: Date
    ) -> StatusObservation {
        StatusObservation(
            id: UUID(), destinationId: destinationId, activity: activity, attention: attention, evidenceKind: .domSignal,
            observedAt: receivedAt, receivedAt: receivedAt, expiresAt: receivedAt.addingTimeInterval(15), sequence: 1,
            connectionEpoch: "e", adapterVersion: "0.1.0"
        )
    }
}
