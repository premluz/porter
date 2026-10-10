import CoreGraphics
import Foundation

public enum PanelOrientation: Sendable, Equatable {
    case vertical, horizontal
}

/// Where the panel rests when it is not open.
public enum RestState: Sendable, Equatable {
    /// A small tab on the screen edge. `anchor` is its vertical centre as a fraction of the visible height, from the top.
    case docked(edge: PanelEdge, anchor: CGFloat)
    /// The capsule, free anywhere. `center` is a fraction of the visible frame, from the top left.
    case floating(center: CGPoint)
}

public enum SnapDecision: Sendable, Equatable {
    case dock(edge: PanelEdge, anchor: CGFloat)
    case float(center: CGPoint)
}

/// All the geometry of the three panel states, as pure functions of the visible screen. Frames are in screen
/// coordinates (AppKit, origin at the bottom left) and in whole points.
public enum DockGeometry {
    // MARK: Sizes

    /// The capsule in either orientation: the open button, then the dots, then an overflow mark if there is one.
    public static func capsuleSize(orientation: PanelOrientation, dotCount: Int, hasOverflow: Bool) -> CGSize {
        let dots = min(max(dotCount, 0), Tokens.Capsule.maximumDots)
        let run = CGFloat(dots) * Tokens.Size.capsuleDot + CGFloat(max(dots - 1, 0)) * Tokens.Space.xs
        let overflow = hasOverflow ? Tokens.Size.capsuleDot : 0
        let length = Tokens.Space.m * 2 + Tokens.Size.expandButton + Tokens.Space.s + run + (dots > 0 ? Tokens.Space.s : 0) + overflow
        switch orientation {
        case .vertical: return CGSize(width: Tokens.Size.capsuleWidth, height: length.rounded(.up))
        case .horizontal: return CGSize(width: length.rounded(.up), height: Tokens.Size.capsuleWidth)
        }
    }

    /// The docked tab's body: it shows up to a few marks, one at least so it is never an empty bump.
    public static func tabSize(markCount: Int) -> CGSize {
        let marks = min(max(markCount, 1), Tokens.Dock.maximumMarks)
        let height = Tokens.Dock.tabPadding * 2 + CGFloat(marks) * Tokens.Dock.markSize + CGFloat(marks - 1) * Tokens.Dock.markGap
        return CGSize(width: Tokens.Dock.tabDepth, height: height.rounded(.up))
    }

    // MARK: Frames

    /// The docked tab: flush with the screen edge, centred on the anchor and kept clear of the screen's top and bottom
    /// by its own flare, which curves out along the edge on both sides.
    public static func tabFrame(edge: PanelEdge, anchor: CGFloat, markCount: Int, in screen: CGRect) -> CGRect {
        let size = tabSize(markCount: markCount)
        let x = edge == .right ? screen.maxX - size.width : screen.minX
        return CGRect(origin: CGPoint(x: x, y: verticalOrigin(height: size.height, anchor: anchor, in: screen, clearance: Tokens.Dock.flareRadius)), size: size)
    }

    /// The tab and its flares: the part of the window the tab's shape can reach.
    public static func tabWindowFrame(_ tab: CGRect) -> CGRect {
        CGRect(x: tab.minX, y: tab.minY - Tokens.Dock.flareRadius, width: tab.width, height: tab.height + 2 * Tokens.Dock.flareRadius)
    }

    /// The capsule peeking out of a docked tab, or the capsule at an edge: the same place the panel has always had.
    public static func edgeCapsuleFrame(edge: PanelEdge, anchor: CGFloat, size: CGSize, in screen: CGRect) -> CGRect {
        let margin = Tokens.Size.edgeMargin
        let x = (edge == .right ? screen.maxX - size.width - margin : screen.minX + margin).rounded(.down)
        return CGRect(origin: CGPoint(x: x, y: verticalOrigin(height: size.height, anchor: anchor, in: screen, clearance: margin)), size: size)
    }

    /// The floating capsule: centred where it was left, but never off the screen. The orientation is chosen from the
    /// room at that place, with a little hysteresis so a capsule held near a limit does not flip back and forth.
    public static func floatingFrame(
        center: CGPoint, orientation: PanelOrientation, dotCount: Int, hasOverflow: Bool, in screen: CGRect
    ) -> CGRect {
        let size = capsuleSize(orientation: orientation, dotCount: dotCount, hasOverflow: hasOverflow)
        let margin = Tokens.Size.edgeMargin
        let cx = screen.minX + min(max(center.x, 0), 1) * screen.width
        let cy = screen.maxY - min(max(center.y, 0), 1) * screen.height
        let x = min(max((cx - size.width / 2).rounded(), screen.minX + margin), max(screen.maxX - size.width - margin, screen.minX + margin))
        let y = min(max((cy - size.height / 2).rounded(), screen.minY + margin), max(screen.maxY - size.height - margin, screen.minY + margin))
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Vertical while it fits at that height; horizontal when the screen's top or bottom leaves too little room. Once
    /// horizontal it needs `reflowSlack` more room than the bare minimum to go back, so the choice does not flicker.
    public static func orientation(
        center: CGPoint, current: PanelOrientation, dotCount: Int, hasOverflow: Bool, in screen: CGRect
    ) -> PanelOrientation {
        let height = capsuleSize(orientation: .vertical, dotCount: dotCount, hasOverflow: hasOverflow).height
        let margin = Tokens.Size.edgeMargin
        let cy = screen.maxY - min(max(center.y, 0), 1) * screen.height
        let slack = current == .horizontal ? Tokens.Dock.reflowSlack : 0
        let fits = cy - height / 2 >= screen.minY + margin + slack && cy + height / 2 <= screen.maxY - margin - slack
        return fits && height + 2 * margin <= screen.height ? .vertical : .horizontal
    }

    /// The open pane for a floating capsule: level with it, on the side with more room, kept on the screen.
    public static func floatingPaneFrame(capsule: CGRect, paneSize: CGSize, in screen: CGRect) -> CGRect {
        let margin = Tokens.Size.edgeMargin
        let opensLeft = capsule.midX > screen.midX
        let x = opensLeft ? capsule.maxX - paneSize.width : capsule.minX
        let y = capsule.midY - paneSize.height / 2
        return CGRect(
            x: min(max(x.rounded(), screen.minX + margin), screen.maxX - paneSize.width - margin),
            y: min(max(y.rounded(), screen.minY + margin), screen.maxY - paneSize.height - margin),
            width: paneSize.width, height: paneSize.height
        )
    }

    // MARK: Dragging

    /// What releasing the capsule here does: dock if it is close to an edge, otherwise stay where it is.
    public static func snap(dragCenter point: CGPoint, in screen: CGRect) -> SnapDecision {
        let toLeft = point.x - screen.minX
        let toRight = screen.maxX - point.x
        let edge: PanelEdge = toRight <= toLeft ? .right : .left
        if min(toLeft, toRight) <= Tokens.Dock.snapDistance {
            return .dock(edge: edge, anchor: fraction(fromTop: point.y, in: screen))
        }
        return .float(center: CGPoint(x: (point.x - screen.minX) / screen.width, y: fraction(fromTop: point.y, in: screen)))
    }

    /// While dragging, a capsule near an edge is drawn towards it: the nearer, the stronger, with no pull beyond
    /// `pullDistance`. Returns where to draw the capsule's centre and how strongly it is pulled (0...1).
    public static func magnet(dragCenter point: CGPoint, restingCenterX: (PanelEdge) -> CGFloat, in screen: CGRect) -> (center: CGPoint, strength: CGFloat) {
        let toLeft = point.x - screen.minX
        let toRight = screen.maxX - point.x
        let edge: PanelEdge = toRight <= toLeft ? .right : .left
        let distance = min(toLeft, toRight)
        guard distance < Tokens.Dock.pullDistance else { return (point, 0) }
        let t = min(max(1 - distance / Tokens.Dock.pullDistance, 0), 1)
        let strength = t * t * (3 - 2 * t)
        let target = restingCenterX(edge)
        return (CGPoint(x: point.x + (target - point.x) * strength, y: point.y), strength)
    }

    /// Whether a docked tab (or the capsule peeking out of it) has been dragged far enough from its edge to come away.
    public static func hasDetached(dragCenter point: CGPoint, edge: PanelEdge, in screen: CGRect) -> Bool {
        let distance = edge == .right ? screen.maxX - point.x : point.x - screen.minX
        return distance > Tokens.Dock.detachDistance + Tokens.Size.capsuleWidth / 2
    }

    // MARK: Helpers

    static func fraction(fromTop y: CGFloat, in screen: CGRect) -> CGFloat {
        min(max((screen.maxY - y) / screen.height, 0), 1)
    }

    private static func verticalOrigin(height: CGFloat, anchor: CGFloat, in screen: CGRect, clearance: CGFloat) -> CGFloat {
        let clamped = min(height, screen.height - 2 * clearance).rounded(.down)
        let centre = screen.maxY - min(max(anchor, 0), 1) * screen.height
        let lowest = (screen.minY + clearance).rounded(.up)
        let highest = max((screen.maxY - clamped - clearance).rounded(.down), lowest)
        return min(max((centre - clamped / 2).rounded(), lowest), highest)
    }
}
