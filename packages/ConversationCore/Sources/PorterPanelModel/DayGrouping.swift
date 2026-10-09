import Foundation

public struct ItemGroup: Equatable, Identifiable, Sendable {
    public var id: String { title }
    public let title: String
    public let items: [PanelItem]
}

/// Groups a recency-ordered list under the day each item was last used, the way the chat apps do: Today, Yesterday,
/// "2 days ago" and so on. An item with no known time is not given a day; it goes under "Open", which says only that
/// it is open. Neighbouring items with the same label share one header, so a list that is not strictly in time order
/// (while the pane is open, new activity joins at the end) never hides or reorders anything.
public enum DayGrouping {
    public static let unknownTitle = "Open"
    /// Past this many days a plain date is clearer than a count.
    static let relativeDays = 6

    public static func groups(_ items: [PanelItem], now: Date, calendar: Calendar = .current) -> [ItemGroup] {
        var groups: [ItemGroup] = []
        for item in items {
            let label = title(for: item.lastActiveAt, now: now, calendar: calendar)
            if let last = groups.last, last.title == label {
                groups[groups.count - 1] = ItemGroup(title: label, items: last.items + [item])
            } else {
                groups.append(ItemGroup(title: label, items: [item]))
            }
        }
        return groups
    }

    public static func title(for date: Date?, now: Date, calendar: Calendar = .current) -> String {
        guard let date else { return unknownTitle }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0: return "Today"
        case 1: return "Yesterday"
        case 2...relativeDays: return "\(days) days ago"
        default:
            var style = Date.FormatStyle(calendar: calendar).day().month(.abbreviated)
            style.timeZone = calendar.timeZone
            return date.formatted(style)
        }
    }
}
