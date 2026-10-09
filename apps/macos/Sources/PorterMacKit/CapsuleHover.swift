import CoreGraphics
import Foundation

/// The geometry of hovering a dot in the collapsed capsule, kept free of AppKit so it can be tested.
enum CapsuleHover {
    /// Which dot the pointer is over. Dots are small and close together, so each is grown by half the gap between them,
    /// which leaves no dead strip between two dots where the label would flicker off and on.
    static func item(
        at point: CGPoint, frames: [String: CGRect], horizontalReach: CGFloat = Tokens.Size.capsuleWidth,
        verticalReach: CGFloat = Tokens.Space.xs / 2
    ) -> String? {
        frames.first { $0.value.insetBy(dx: -horizontalReach, dy: -verticalReach).contains(point) }?.key
    }

    /// Where the label goes, in screen coordinates: beside the capsule on the side facing the screen, level with the
    /// dot, and kept on screen.
    static func tooltipFrame(anchor: CGRect, size: CGSize, window: CGRect, edge: PanelEdge, visible: CGRect) -> CGRect {
        let gap = Tokens.Space.s
        let x = edge == .right ? window.minX - gap - size.width : window.maxX + gap
        var y = anchor.midY - size.height / 2
        y = min(max(y, visible.minY + Tokens.Size.edgeMargin), visible.maxY - size.height - Tokens.Size.edgeMargin)
        return CGRect(x: max(x, visible.minX), y: y, width: size.width, height: size.height)
    }

    /// A dot's frame in the window's own top-left coordinates, as a rectangle on screen.
    static func screenRect(of frame: CGRect, inWindow window: CGRect) -> CGRect {
        CGRect(x: window.minX + frame.minX, y: window.maxY - frame.maxY, width: frame.width, height: frame.height)
    }
}
