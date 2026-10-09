import ConversationCore
import Foundation

/// Words for status. Colour is never the only cue, and a stale observation never reads as live.
public enum StatusPresentation {
    public static func label(for status: ItemStatus) -> String {
        guard status.freshness == .fresh else { return staleLabel(for: status) }
        return name(of: status.display)
    }

    public static func age(seconds: Int) -> String {
        switch seconds {
        case ..<60: "just now"
        case ..<3_600: "\(seconds / 60) min ago"
        case ..<86_400: "\(seconds / 3_600) h ago"
        default: "\(seconds / 86_400) d ago"
        }
    }

    public static func accessibilityLabel(for item: PanelItem) -> String {
        var parts = [item.title, ProviderNames.display(item.provider)]
        if let source = item.source { parts.append("in \(source.label)") }
        if let alias = item.profileAlias { parts.append("profile \(alias)") }
        parts.append(label(for: item.status))
        switch item.availability {
        case .open(let routes) where routes.count > 1: parts.append("open in \(routes.count) tabs, choose one")
        case .open: break
        case .unavailable(.closed): parts.append("not open")
        case .unavailable(.sourceOffline): parts.append("browser not connected")
        }
        if item.pinned { parts.append("pinned") }
        return parts.joined(separator: ", ")
    }

    /// "Last seen working 5 min ago": a cached observation, never a live claim.
    private static func staleLabel(for status: ItemStatus) -> String {
        guard let seconds = status.ageSeconds, let seen = status.lastKnown, seen != .unknown else { return "Unknown" }
        return "Last seen \(name(of: seen).lowercased()) \(age(seconds: seconds))"
    }

    private static func name(of display: DisplayStatus) -> String {
        switch display {
        case .needsUser: "Needs you"
        case .working: "Working"
        case .newResponse: "New response"
        case .idle: "Idle"
        case .unknown: "Unknown"
        }
    }
}
