import CoreGraphics
import Foundation

/// One element of another application's accessibility tree. A protocol so adapters and the connector can be
/// tested on synthetic trees; nodes are created and used inside one `withWindow` call and never kept.
public protocol AccessibilityNode {
    var role: String { get }
    /// The first of the element's title, description and value that is not empty.
    var label: String { get }
    var frame: CGRect? { get }
    var children: [any AccessibilityNode] { get }
    /// Presses this element, or the nearest ancestor that can be pressed. False if nothing could be.
    func press() -> Bool
}

public enum AccessibilityError: Error, Equatable {
    /// The user has not allowed Porter under Privacy & Security → Accessibility.
    case notTrusted
    case notRunning
    /// The app is running but shows no window to read (hidden, minimised or on another desktop).
    case noWindow
}

public protocol AccessibilityProviding: Sendable {
    var isTrusted: Bool { get }
    func isRunning(bundleId: String) -> Bool
    /// Runs `body` on the app's main window. The tree must not outlive the call.
    func withWindow<Result: Sendable>(
        bundleId: String, _ body: @escaping @Sendable (any AccessibilityNode) throws -> Result
    ) async throws -> Result
    func bringForward(bundleId: String)
}

/// A node inside a window's sidebar strip, in reading order.
public struct StripNode {
    public let role: String
    public let label: String
    public let node: any AccessibilityNode
}

public enum SidebarStrip {
    static let maximumNodes = 6_000

    /// Everything in the leftmost `width` points of the window, in tree order. A synthetic bound on both size and
    /// position keeps message content, which sits in the middle of the window, out of reach.
    public static func nodes(in window: any AccessibilityNode, width: CGFloat) -> [StripNode] {
        guard let origin = window.frame?.minX else { return [] }
        var result: [StripNode] = []
        var visited = 0
        func visit(_ node: any AccessibilityNode, depth: Int) {
            guard visited < maximumNodes, depth < 40 else { return }
            visited += 1
            if let frame = node.frame, frame.maxX <= origin + width {
                result.append(StripNode(role: node.role, label: node.label, node: node))
            }
            for child in node.children { visit(child, depth: depth + 1) }
        }
        visit(window, depth: 0)
        return result
    }
}
