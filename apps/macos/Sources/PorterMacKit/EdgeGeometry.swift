import CoreGraphics
import Foundation

public enum PanelEdge: String, Sendable, CaseIterable, Equatable {
    case left, right
}

/// Where the panel sits. Pure geometry: the window is always exactly the visible shape, so there
/// are no transparent regions that could swallow desktop clicks.
public enum EdgeGeometry {
    public static func capsuleFrame(
        in screen: CGRect, edge: PanelEdge, anchor: CGFloat, dotCount: Int, hasOverflow: Bool
    ) -> CGRect {
        let dots = min(max(dotCount, 0), Tokens.Capsule.maximumDots)
        let dotColumn = CGFloat(dots) * Tokens.Size.capsuleDot + CGFloat(max(dots - 1, 0)) * Tokens.Space.xs
        let overflow = hasOverflow ? Tokens.Size.capsuleDot : 0
        let height = Tokens.Space.m * 2 + Tokens.Size.expandButton + Tokens.Space.s
            + dotColumn + (dots > 0 ? Tokens.Space.s : 0) + overflow
        return frame(width: Tokens.Size.capsuleWidth, height: height, in: screen, edge: edge, anchor: anchor)
    }

    public static func paneFrame(in screen: CGRect, edge: PanelEdge, anchor: CGFloat, rowCount: Int, sectionCount: Int) -> CGRect {
        let wanted = Tokens.Size.headerHeight + Tokens.Size.footerHeight
            + CGFloat(rowCount) * Tokens.Size.rowHeight + CGFloat(sectionCount) * Tokens.Size.sectionHeaderHeight
            + Tokens.Space.l
        let available = screen.height - 2 * Tokens.Size.edgeMargin
        let height = min(max(wanted, Tokens.Size.minimumPaneHeight), available)
        return frame(width: Tokens.Size.paneWidth, height: height, in: screen, edge: edge, anchor: anchor)
    }

    /// 0 at the capsule, 1 at the pane, from the live window width during the animation.
    public static func progress(width: CGFloat) -> CGFloat {
        let span = Tokens.Size.paneWidth - Tokens.Size.capsuleWidth
        return min(max((width - Tokens.Size.capsuleWidth) / span, 0), 1)
    }

    public static func cornerRadius(progress: CGFloat) -> CGFloat {
        Tokens.Size.capsuleCorner + (Tokens.Size.paneCorner - Tokens.Size.capsuleCorner) * progress
    }

    public static func capsuleContentOpacity(progress: CGFloat) -> CGFloat {
        min(max(1 - progress / Tokens.Motion.contentRevealStart, 0), 1)
    }

    public static func paneContentOpacity(progress: CGFloat) -> CGFloat {
        min(max((progress - Tokens.Motion.contentRevealStart) / (1 - Tokens.Motion.contentRevealStart), 0), 1)
    }

    /// Anchor is the vertical centre as a fraction of the visible screen height, from the top.
    /// Frames are whole points: AppKit snaps window frames to the pixel grid, so a half-point result
    /// here would disagree with the real window by exactly that half point.
    private static func frame(width: CGFloat, height: CGFloat, in screen: CGRect, edge: PanelEdge, anchor: CGFloat) -> CGRect {
        let margin = Tokens.Size.edgeMargin
        let clampedHeight = min(height, screen.height - 2 * margin).rounded(.down)
        let x = (edge == .right ? screen.maxX - width - margin : screen.minX + margin).rounded(.down)
        let centre = screen.maxY - min(max(anchor, 0), 1) * screen.height
        let lowest = (screen.minY + margin).rounded(.up)
        let highest = max((screen.maxY - clampedHeight - margin).rounded(.down), lowest)
        let y = min(max((centre - clampedHeight / 2).rounded(), lowest), highest)
        return CGRect(x: x, y: y, width: width, height: clampedHeight)
    }
}
