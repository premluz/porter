import Foundation

/// A conversation listed in an app's sidebar, as read.
public struct SidebarEntry: Equatable, Sendable {
    public let title: String
    public let unread: Bool

    public init(title: String, unread: Bool = false) {
        self.title = title
        self.unread = unread
    }
}

public enum SidebarReading: Equatable, Sendable {
    case entries([SidebarEntry])
    /// The sidebar is hidden or its layout is not one this adapter knows; said plainly instead of reporting "no chats".
    case unrecognised(String)
}

/// The knowledge about one desktop chat app: where its conversations are in its accessibility tree and how to open one.
/// Adding an app is adding an adapter and its bundle id to `LocatorPolicy`.
public protocol DesktopAppAdapter: Sendable {
    var bundleId: String { get }
    var provider: String { get }
    var displayName: String { get }
    var adapterVersion: String { get }
    func read(_ window: any AccessibilityNode) -> SidebarReading
    /// The control that opens `entry`, found again from the current tree; `ordinal` picks among equal titles.
    func control(for entry: SidebarEntry, ordinal: Int, in window: any AccessibilityNode) -> (any AccessibilityNode)?
}

extension DesktopAppAdapter {
    /// Width of the sidebar strip read. Wider than any sidebar seen, narrower than the message area.
    static var stripWidth: CGFloat { 300 }
}
