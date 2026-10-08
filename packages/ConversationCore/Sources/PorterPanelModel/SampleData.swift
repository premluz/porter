import ConversationCore
import Foundation
import PorterStore

/// One labelled sample route, with what a scripted activation should answer and a made-up observation.
public struct SampleEntry: Sendable {
    public let row: DestinationRow
    public let outcome: ActivationOutcome
    /// What a sample observation said and how long ago, or nil for no observation at all.
    public let observed: (display: DisplayStatus, ageSeconds: Int)?
}

/// Sample conversations covering every state the panel and the phone list can show. They are
/// never presented as real, and their links point nowhere.
public enum SampleData {
    public static let personal = "chrome-sample-personal"
    public static let work = "chrome-sample-work"
    public static let offline = "chrome-sample-offline"
    /// Past this many seconds an observation is stale and must not read as live.
    public static let freshSeconds = 60

    public static let connectors = [
        ConnectorSummary(connectorId: personal, profileAlias: "Personal", reachability: .connected, routeCount: 5),
        ConnectorSummary(connectorId: work, profileAlias: "Work", reachability: .connected, routeCount: 2),
        ConnectorSummary(connectorId: offline, profileAlias: "Sample", reachability: .disconnected, routeCount: 0),
    ]

    /// Seconds since each sample chat was last used, so sample mode shows the newest-first ordering.
    public static let entries: [SampleEntry] = [
        entry("sample-1", "Release plan", personal, "Personal", tab: 1, .activated, .working, 20, usedAgo: 120),
        entry("sample-2", "Release plan", work, "Work", tab: 1, .activated, .needsUser, 45, usedAgo: 900),
        entry("sample-3", "Design review", personal, "Personal", tab: 2, .activated, .newResponse, 10, usedAgo: 8),
        entry("sample-3", "Design review", personal, "Personal", tab: 3, .targetGone, .newResponse, 10, usedAgo: 4_000),
        entry("sample-4", "Quarterly numbers", work, "Work", tab: 2, .timeout, .idle, 30, usedAgo: 3_600),
        entry("sample-5", "Unlabelled chat", personal, "Personal", tab: 4, .targetChanged, nil, 0, usedAgo: nil),
        entry("sample-6", "Last week's draft", personal, "Personal", tab: 5, .accountChanged, .working, 900, usedAgo: 604_800),
    ]

    /// Pins that exercise the closed-tab and offline-source states.
    public static func seedPins(into store: PreferenceStore, at date: Date) async throws(StoreError) {
        for (chat, title, connector) in [
            ("sample-closed", "Old research thread", personal), ("sample-offline", "Archived notes", offline),
        ] {
            let key = try ConversationKey(provider: "claude", connectorId: connector, providerConversationId: chat)
            try await store.pin(
                ConversationSnapshot(key: key, title: title, canonicalUrl: "https://claude.ai/chat/\(chat)", profileAlias: "Sample"),
                at: date
            )
        }
    }

    public static func status(of entry: SampleEntry, now: Date) -> DestinationStatus? {
        guard let observed = entry.observed else { return nil }
        let received = now.addingTimeInterval(-TimeInterval(observed.ageSeconds))
        let observation = StatusObservation(
            id: UUID(), destinationId: entry.row.destinationId, activity: observed.display == .working ? .working : .idle,
            attention: observed.display == .needsUser ? .needsUser : (observed.display == .newResponse ? .newResponse : .none),
            evidenceKind: .domSignal, observedAt: received, receivedAt: received, expiresAt: received.addingTimeInterval(15),
            sequence: 1, connectionEpoch: "sample", adapterVersion: "0.0.0"
        )
        let fresh = observed.ageSeconds <= freshSeconds
        return DestinationStatus(
            display: fresh ? observed.display : .unknown, freshness: fresh ? .fresh : .stale,
            reachability: .connected, lastKnown: observation
        )
    }

    private static func entry(
        _ chat: String, _ title: String, _ connector: String, _ alias: String, tab: Int,
        _ outcome: ActivationOutcome, _ display: DisplayStatus?, _ age: Int, usedAgo: TimeInterval?
    ) -> SampleEntry {
        let row = DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: chat, provider: "claude",
            title: title, profileAlias: alias, connectorId: connector, reachability: .connected, tabId: tab,
            windowId: 1, url: "https://claude.ai/chat/\(chat)", routeCount: 1,
            lastActiveAt: usedAgo.map { Date().addingTimeInterval(-$0) }
        )
        return SampleEntry(row: row, outcome: outcome, observed: display.map { ($0, age) })
    }
}
