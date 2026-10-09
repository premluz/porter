import Foundation

/// The Claude desktop app. Its sidebar lists project groups ("Toggle sessions for ..." with the project's name beside
/// it), dated groups, and then chats as plain text. Seen in one state only (version 2.31226.0, sidebar open), so a
/// layout without any text in the strip is reported as unrecognised rather than as an empty list.
public struct ClaudeDesktopAdapter: DesktopAppAdapter {
    public let bundleId = "com.anthropic.claudefordesktop"
    public let provider = "claude-desktop"
    public let displayName = "Claude"
    public let adapterVersion = "0.1.0"

    private static let projectButtonPrefix = "Toggle sessions for "
    private static let chrome: Set<String> = ["View all", "Claude", "Code", "Get apps and extensions"]

    public init() {}

    private func entryNodes(_ window: any AccessibilityNode) -> [StripNode] {
        let strip = SidebarStrip.nodes(in: window, width: Self.stripWidth)
        // A project's own name follows its toggle button; it is a group label, not a chat.
        var projectNames: Set<String> = []
        for item in strip where item.role == "AXButton" && item.label.hasPrefix(Self.projectButtonPrefix) {
            projectNames.insert(String(item.label.dropFirst(Self.projectButtonPrefix.count)))
        }
        return strip.filter { item in
            item.role == "AXStaticText" && !item.label.isEmpty && !Self.chrome.contains(item.label)
                && !projectNames.contains(item.label)
        }
    }

    public func read(_ window: any AccessibilityNode) -> SidebarReading {
        let nodes = entryNodes(window)
        guard !nodes.isEmpty else { return .unrecognised("no conversation list is visible; open the sidebar") }
        return .entries(nodes.map { SidebarEntry(title: $0.label) })
    }

    public func control(for entry: SidebarEntry, ordinal: Int, in window: any AccessibilityNode) -> (any AccessibilityNode)? {
        let matches = entryNodes(window).filter { $0.label == entry.title }
        return matches.indices.contains(ordinal) ? matches[ordinal].node : nil
    }
}
