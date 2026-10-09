import Foundation

/// The Claude desktop app. Its sidebar lists project groups ("Toggle sessions for ..." with the project's name beside
/// it), dated groups ("Yesterday", "Oct 7", "Older" as buttons), and then chats as plain text under each. Seen in one
/// state only (version 2.31226.0, sidebar open), so a layout without any text in the strip is reported as
/// unrecognised rather than as an empty list.
public struct ClaudeDesktopAdapter: DesktopAppAdapter {
    public let bundleId = "com.anthropic.claudefordesktop"
    public let provider = "claude-desktop"
    public let displayName = "Claude"
    public let adapterVersion = "0.1.0"

    private static let projectButtonPrefix = "Toggle sessions for "
    private static let chrome: Set<String> = ["View all", "Claude", "Code", "Get apps and extensions"]
    private static let headingNames: Set<String> = ["Today", "Yesterday", "Older"]

    public init() {}

    private static func isHeading(_ text: String) -> Bool {
        headingNames.contains(text) || text.wholeMatch(of: /[A-Z][a-z]{2} \d{1,2}/) != nil
    }

    private struct Found {
        let node: StripNode
        let section: String?
    }

    /// Chats in reading order, each with the heading above it. A project's own name follows its toggle button; it is
    /// a group label, not a chat, and so are the headings, the app's navigation and its "View all" links.
    private func found(_ window: any AccessibilityNode) -> [Found] {
        let strip = SidebarStrip.nodes(in: window, width: Self.stripWidth)
        var projectNames: Set<String> = []
        for item in strip where item.role == "AXButton" && item.label.hasPrefix(Self.projectButtonPrefix) {
            projectNames.insert(String(item.label.dropFirst(Self.projectButtonPrefix.count)))
        }
        var section: String?
        var result: [Found] = []
        for item in strip {
            if item.role == "AXButton" {
                if Self.isHeading(item.label) { section = item.label }
                continue
            }
            guard item.role == "AXStaticText", !item.label.isEmpty, !Self.chrome.contains(item.label),
                  !projectNames.contains(item.label), !Self.isHeading(item.label) else { continue }
            result.append(Found(node: item, section: section))
        }
        return result
    }

    public func read(_ window: any AccessibilityNode) -> SidebarReading {
        let chats = found(window)
        guard !chats.isEmpty else { return .unrecognised("no conversation list is visible; open the sidebar") }
        return .entries(chats.map { SidebarEntry(title: $0.node.label, section: $0.section) })
    }

    public func control(for entry: SidebarEntry, ordinal: Int, in window: any AccessibilityNode) -> (any AccessibilityNode)? {
        let matches = found(window).filter { $0.node.label == entry.title }
        return matches.indices.contains(ordinal) ? matches[ordinal].node.node : nil
    }
}
