import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("Chats are grouped by the day they were last used")
struct DayGroupingTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }

    /// Wednesday 2026-10-07, 10:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_791_367_200)

    private func row(_ chat: String, hoursAgo: Double?) -> DestinationRow {
        DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: chat, provider: "claude",
            title: chat, profileAlias: "Personal", connectorId: Fixture.personal, reachability: .connected, tabId: chat.hashValue & 0xffff,
            windowId: 1, url: nil, routeCount: 1, lastActiveAt: hoursAgo.map { Date(timeIntervalSince1970: 1_791_367_200 - $0 * 3600) }
        )
    }

    private func titles(_ hours: [Double?]) -> [String] {
        let rows = hours.enumerated().map { row("c\($0.offset)", hoursAgo: $0.element) }
        let snapshot = Fixture.build(rows: rows)
        return DayGrouping.groups(snapshot.open, now: now, calendar: calendar).map(\.title)
    }

    @Test("today, yesterday and a count of days, by calendar day and not by hours")
    func labels() {
        // 10:00 now: 9 hours ago is still today, 11 hours ago is yesterday, 35 hours ago is two days back.
        #expect(DayGrouping.title(for: now.addingTimeInterval(-9 * 3600), now: now, calendar: calendar) == "Today")
        #expect(DayGrouping.title(for: now.addingTimeInterval(-11 * 3600), now: now, calendar: calendar) == "Yesterday")
        #expect(DayGrouping.title(for: now.addingTimeInterval(-35 * 3600), now: now, calendar: calendar) == "2 days ago")
        #expect(DayGrouping.title(for: now.addingTimeInterval(-6 * 24 * 3600), now: now, calendar: calendar) == "6 days ago")
        #expect(DayGrouping.title(for: now.addingTimeInterval(60), now: now, calendar: calendar) == "Today")
    }

    @Test("beyond a week the date is shown, and an unknown time is just Open")
    func olderAndUnknown() {
        #expect(DayGrouping.title(for: now.addingTimeInterval(-9 * 24 * 3600), now: now, calendar: calendar) == "Sep 28")
        #expect(DayGrouping.title(for: nil, now: now, calendar: calendar) == "Open")
    }

    @Test("neighbours with one label share a header; the order of items is kept")
    func grouping() {
        #expect(titles([1, 2, 12, 36, nil, nil]) == ["Today", "Yesterday", "2 days ago", "Open"])
        let rows = [row("a", hoursAgo: 1), row("b", hoursAgo: 2), row("c", hoursAgo: 40)]
        let snapshot = Fixture.build(rows: rows)
        let groups = DayGrouping.groups(snapshot.open, now: now, calendar: calendar)
        #expect(groups.map { $0.items.map(\.title) } == [["a", "b"], ["c"]])
    }

    @Test("a late arrival at the end does not merge into an earlier header, so nothing moves")
    func lateArrival() {
        let rows = [row("a", hoursAgo: 40), row("b", hoursAgo: 1)]
        let shownFirst = Fixture.build(rows: [rows[0]]).open[0].id
        let items = Fixture.build(rows: rows, frozen: [shownFirst]).open
        #expect(DayGrouping.groups(items, now: now, calendar: calendar).map(\.title) == ["2 days ago", "Today"])
    }
}
