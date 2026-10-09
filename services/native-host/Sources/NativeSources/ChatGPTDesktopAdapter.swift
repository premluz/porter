import Foundation

/// The OpenAI desktop app named "ChatGPT" (bundle `com.openai.codex`). Its sidebar has projects, then a "Recents"
/// button followed by one button and one text per chat, with an "Unread" text before a chat that has unread
/// replies. Seen in one state only (version 26.1002.52244). Without a "Recents" header the layout is unrecognised.
public struct ChatGPTDesktopAdapter: DesktopAppAdapter {
    public let bundleId = "com.openai.codex"
    public let provider = "chatgpt-desktop"
    public let displayName = "ChatGPT"
    public let adapterVersion = "0.1.0"

    private static let recentsHeader = "Recents"
    private static let unreadMarker = "Unread"
    private static let chrome: Set<String> = ["Recents", "New chat", "Pin chat", "Unread"]

    public init() {}

    private struct Row {
        let entry: SidebarEntry
        let button: StripNode?
    }

    private func rows(_ window: any AccessibilityNode) -> [Row]? {
        let strip = SidebarStrip.nodes(in: window, width: Self.stripWidth)
        guard let header = strip.firstIndex(where: { $0.role == "AXButton" && $0.label == Self.recentsHeader }) else { return nil }
        var rows: [Row] = []
        var unread = false
        for item in strip[(header + 1)...] {
            if item.role == "AXStaticText" {
                if item.label == Self.unreadMarker { unread = true; continue }
                guard !item.label.isEmpty, !Self.chrome.contains(item.label) else { continue }
                let button = strip.first { $0.role == "AXButton" && $0.label == item.label }
                rows.append(Row(entry: SidebarEntry(title: item.label, unread: unread), button: button))
                unread = false
            }
        }
        return rows
    }

    public func read(_ window: any AccessibilityNode) -> SidebarReading {
        guard let rows = rows(window) else { return .unrecognised("no Recents list is visible; open the sidebar") }
        return .entries(rows.map(\.entry))
    }

    public func control(for entry: SidebarEntry, ordinal: Int, in window: any AccessibilityNode) -> (any AccessibilityNode)? {
        let matches = (rows(window) ?? []).filter { $0.entry.title == entry.title }
        guard matches.indices.contains(ordinal) else { return nil }
        let strip = SidebarStrip.nodes(in: window, width: Self.stripWidth)
        // Equal titles have equal buttons; the nth button is the nth entry's.
        let buttons = strip.filter { $0.role == "AXButton" && $0.label == entry.title }
        return buttons.indices.contains(ordinal) ? buttons[ordinal].node : matches[ordinal].button?.node
    }
}
