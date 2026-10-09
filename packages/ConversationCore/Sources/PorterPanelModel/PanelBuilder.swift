import ConversationCore
import Foundation
import PorterStore

public struct PanelInputs: Sendable {
    public var rows: [DestinationRow]
    public var connectors: [ConnectorSummary]
    public var records: [PreferenceRecord]
    public var statuses: [UUID: DestinationStatus]
    public var query: String
    public var showHidden: Bool
    /// Item IDs in the order currently on screen. While the user is pointing or arrowing, items
    /// keep these positions and anything new goes to the end, so nothing moves under the cursor.
    public var frozenOrder: [String]?
    public var now: Date

    public init(
        rows: [DestinationRow], connectors: [ConnectorSummary], records: [PreferenceRecord],
        statuses: [UUID: DestinationStatus] = [:], query: String = "", showHidden: Bool = false,
        frozenOrder: [String]? = nil, now: Date
    ) {
        self.rows = rows
        self.connectors = connectors
        self.records = records
        self.statuses = statuses
        self.query = query
        self.showHidden = showHidden
        self.frozenOrder = frozenOrder
        self.now = now
    }
}

public enum PanelBuilder {
    public static func build(_ inputs: PanelInputs) -> PanelSnapshot {
        var unreadable: [String] = []
        let groups = group(preferringEnhancedRoutes(inputs.rows, connectors: inputs.connectors), unreadable: &unreadable)
        let recordsByKey = Dictionary(uniqueKeysWithValues: inputs.records.map { ($0.key, $0) })
        let reachable = Set(inputs.connectors.filter { $0.reachability == .connected }.map(\.connectorId))
        var items = openItems(groups, records: recordsByKey, inputs: inputs)
        items += closedPins(inputs.records, openKeys: Set(groups.keys), reachable: reachable, inputs: inputs)
        items = markSharedTitles(items)
        let visible = items.filter { matches($0, query: inputs.query) }
        return snapshot(visible, allItems: items, inputs: inputs, unreadable: unreadable)
    }

    private static func group(_ rows: [DestinationRow], unreadable: inout [String]) -> [ConversationKey: [DestinationRow]] {
        var groups: [ConversationKey: [DestinationRow]] = [:]
        for row in rows {
            do {
                let key = try ConversationKey(provider: row.provider, connectorId: row.connectorId, providerConversationId: row.providerConversationId)
                groups[key, default: []].append(row)
            } catch {
                unreadable.append("route \(row.destinationId): \(error)")
            }
        }
        return groups
    }

    private static func openItems(
        _ groups: [ConversationKey: [DestinationRow]], records: [ConversationKey: PreferenceRecord], inputs: PanelInputs
    ) -> [PanelItem] {
        groups.map { key, rows in
            let sorted = rows.sorted { ($0.tabId ?? 0) < ($1.tabId ?? 0) }
            let record = records[key]
            let first = sorted[0]
            let routes = sorted.map { PanelRoute(destinationId: $0.destinationId, revision: $0.revision, tabId: $0.tabId, windowId: $0.windowId) }
            return PanelItem(
                key: key, title: first.title, provider: first.provider, profileAlias: first.profileAlias,
                canonicalUrl: first.url, pinned: record?.pinned ?? false, hidden: record?.hidden ?? false,
                availability: .open(routes), status: bestStatus(sorted, inputs: inputs), sharesTitle: false,
                lastActiveAt: sorted.compactMap(\.lastActiveAt).max()
            )
        }
    }

    private static func closedPins(
        _ records: [PreferenceRecord], openKeys: Set<ConversationKey>, reachable: Set<String>, inputs: PanelInputs
    ) -> [PanelItem] {
        records.filter { $0.pinned && !openKeys.contains($0.key) }.map { record in
            PanelItem(
                key: record.key, title: record.title, provider: record.key.provider, profileAlias: record.profileAlias,
                canonicalUrl: record.canonicalUrl, pinned: true, hidden: record.hidden,
                availability: .unavailable(reachable.contains(record.key.connectorId) ? .closed : .sourceOffline),
                status: .unknown, sharesTitle: false
            )
        }
    }

    /// Several tabs of one chat vote; only fresh observations count, as for a single route.
    private static func bestStatus(_ rows: [DestinationRow], inputs: PanelInputs) -> ItemStatus {
        let known = rows.compactMap { inputs.statuses[$0.destinationId] }
        guard !known.isEmpty else { return .unknown }
        let display = StatusProjection.conversationDisplay(known)
        let newest = known.compactMap(\.lastKnown).max { $0.receivedAt < $1.receivedAt }
        let age = newest.map { max(0, Int(inputs.now.timeIntervalSince($0.receivedAt))) }
        let freshness: Freshness = known.contains { $0.freshness == .fresh } ? .fresh : (newest == nil ? .unknown : .stale)
        let lastKnown = newest.map(StatusProjection.displayStatus(of:))
        return ItemStatus(display: display, freshness: freshness, ageSeconds: age, lastKnown: lastKnown)
    }

    private static func markSharedTitles(_ items: [PanelItem]) -> [PanelItem] {
        let counts = Dictionary(grouping: items, by: { $0.title.lowercased() }).mapValues(\.count)
        return items.map { item in
            PanelItem(
                key: item.key, title: item.title, provider: item.provider, profileAlias: item.profileAlias,
                canonicalUrl: item.canonicalUrl, pinned: item.pinned, hidden: item.hidden,
                availability: item.availability, status: item.status, sharesTitle: (counts[item.title.lowercased()] ?? 0) > 1,
                lastActiveAt: item.lastActiveAt
            )
        }
    }

    private static func matches(_ item: PanelItem, query: String) -> Bool {
        let terms = query.lowercased().split(whereSeparator: \.isWhitespace)
        let haystack = [item.title, item.provider, item.profileAlias ?? ""].joined(separator: " ").lowercased()
        return terms.allSatisfy { haystack.contains($0) }
    }
}
