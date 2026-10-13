import CoreGraphics
import Foundation

/// Where the panel rests when it is not open.
public enum RestMode: String, Sendable, Equatable {
    case docked, floating
}

/// Everything that decides where the panel's shapes are: the resting place, whether a docked tab is peeking out as the
/// capsule, how many dots and marks there are, and the open pane's size. Pure, so each combination can be tested.
public struct PanelLayout: Sendable, Equatable {
    public var mode: RestMode
    public var edge: PanelEdge
    public var anchor: CGFloat
    public var floatCenter: CGPoint
    public var orientation: PanelOrientation
    public var peeking: Bool
    public var dotCount: Int
    public var hasOverflow: Bool
    public var rowCount: Int
    public var sectionCount: Int

    public init(
        mode: RestMode = .docked, edge: PanelEdge = .right, anchor: CGFloat = 0.5, floatCenter: CGPoint = CGPoint(x: 0.5, y: 0.5),
        orientation: PanelOrientation = .vertical, peeking: Bool = false, dotCount: Int = 0, hasOverflow: Bool = false,
        rowCount: Int = 3, sectionCount: Int = 1
    ) {
        self.mode = mode
        self.edge = edge
        self.anchor = anchor
        self.floatCenter = floatCenter
        self.orientation = orientation
        self.peeking = peeking
        self.dotCount = dotCount
        self.hasOverflow = hasOverflow
        self.rowCount = rowCount
        self.sectionCount = sectionCount
    }

    /// The tab, with nothing peeking, is the only resting shape that is not a capsule.
    public var restIsTab: Bool { mode == .docked && !peeking }

    /// The resting shape's rectangle on screen.
    public func restFrame(in screen: CGRect) -> CGRect {
        if restIsTab { return DockGeometry.tabFrame(edge: edge, anchor: anchor, in: screen) }
        let size = DockGeometry.capsuleSize(orientation: mode == .docked ? .vertical : orientation, dotCount: dotCount, hasOverflow: hasOverflow)
        if mode == .docked { return DockGeometry.edgeCapsuleFrame(edge: edge, anchor: anchor, size: size, in: screen) }
        return DockGeometry.floatingFrame(center: floatCenter, orientation: orientation, dotCount: dotCount, hasOverflow: hasOverflow, in: screen)
    }

    /// The window at rest: exactly the shape, or for the tab the shape and its flares.
    public func restWindow(in screen: CGRect) -> CGRect {
        let frame = restFrame(in: screen)
        return restIsTab ? DockGeometry.tabWindowFrame(frame) : frame
    }

    /// The open pane. Docked, it opens at the edge level with the anchor; floating, level with the capsule.
    public func paneFrame(in screen: CGRect) -> CGRect {
        let docked = EdgeGeometry.paneFrame(in: screen, edge: edge, anchor: anchor, rowCount: rowCount, sectionCount: sectionCount)
        guard mode == .floating else { return docked }
        let capsule = DockGeometry.floatingFrame(center: floatCenter, orientation: orientation, dotCount: dotCount, hasOverflow: hasOverflow, in: screen)
        return DockGeometry.floatingPaneFrame(capsule: capsule, paneSize: docked.size, in: screen)
    }

    /// Which side the pane grows towards, so its content hangs from the right side of its shape.
    public func paneEdge(in screen: CGRect) -> PanelEdge {
        guard mode == .floating else { return edge }
        return restFrame(in: screen).midX > screen.midX ? .right : .left
    }

    public func restSpec(in window: CGRect, screen: CGRect) -> ShapeSpec {
        let local = EdgeGeometry.localRect(of: restFrame(in: screen), in: window)
        if restIsTab {
            let edgeX = (edge == .right ? screen.maxX : screen.minX) - window.minX
            let fusion = EdgeFusion(edge: edge, x: edgeX, reach: Tokens.Dock.flareRadius)
            return ShapeSpec(rect: local, corner: Tokens.Dock.tabCorner, fusion: fusion, edge: edge, kind: .tab)
        }
        let kind: PanelOrientation = mode == .docked ? .vertical : orientation
        return ShapeSpec(rect: local, corner: Tokens.Size.capsuleCorner, edge: mode == .docked ? edge : paneEdge(in: screen), kind: .capsule(kind))
    }

    public func paneSpec(in window: CGRect, screen: CGRect) -> ShapeSpec {
        ShapeSpec(
            rect: EdgeGeometry.localRect(of: paneFrame(in: screen), in: window), corner: Tokens.Size.paneCorner,
            edge: paneEdge(in: screen), kind: .pane
        )
    }
}
