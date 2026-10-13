import CoreGraphics
import SwiftUI

public enum ShapeKind: Sendable, Equatable {
    case tab
    case capsule(PanelOrientation)
    case pane
}

/// Where a shape is fused with the screen edge: which edge, where it is in the window's coordinates, and how far the
/// fillet runs along the edge where the shape meets it. A shape with no fusion is a plain rounded rectangle.
public struct EdgeFusion: Sendable, Equatable {
    public var edge: PanelEdge
    public var x: CGFloat
    public var reach: CGFloat

    public init(edge: PanelEdge, x: CGFloat, reach: CGFloat) {
        self.edge = edge
        self.x = x
        self.reach = reach
    }

    /// Part of the way from one fusion to another; a missing one is the other with no reach. Between two edges, the
    /// first lets go before the second takes hold.
    static func mix(_ a: EdgeFusion?, _ b: EdgeFusion?, _ amount: CGFloat) -> EdgeFusion? {
        guard let a else { return b.map { EdgeFusion(edge: $0.edge, x: $0.x, reach: max($0.reach * amount, 0)) } }
        guard let b else { return EdgeFusion(edge: a.edge, x: a.x, reach: max(a.reach * (1 - amount), 0)) }
        guard a.edge == b.edge else {
            return amount < 0.5
                ? EdgeFusion(edge: a.edge, x: a.x, reach: max(a.reach * (1 - 2 * amount), 0))
                : EdgeFusion(edge: b.edge, x: b.x, reach: max(b.reach * (2 * amount - 1), 0))
        }
        return EdgeFusion(edge: a.edge, x: a.x + (b.x - a.x) * amount, reach: max(a.reach + (b.reach - a.reach) * amount, 0))
    }
}

/// One shape the panel can be: where it is in the window (top-left coordinates), how round, and, for the docked tab,
/// how it is fused with the screen edge. The panel is always a single shape moving between these.
public struct ShapeSpec: Sendable, Equatable {
    public var rect: CGRect
    public var corner: CGFloat
    public var fusion: EdgeFusion?
    public var edge: PanelEdge
    public var kind: ShapeKind

    public init(rect: CGRect, corner: CGFloat, fusion: EdgeFusion? = nil, edge: PanelEdge, kind: ShapeKind) {
        self.rect = rect
        self.corner = corner
        self.fusion = fusion
        self.edge = edge
        self.kind = kind
    }

    /// Part of the way to `other` (progress 0 is this shape, 1 is the other); overshoot is kept, so a bounce shows.
    public func blended(toward other: ShapeSpec, _ progress: Double) -> ShapeSpec {
        let amount = CGFloat(progress)
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * amount }
        return ShapeSpec(
            rect: CGRect(
                x: mix(rect.minX, other.rect.minX), y: mix(rect.minY, other.rect.minY),
                width: max(mix(rect.width, other.rect.width), 0), height: max(mix(rect.height, other.rect.height), 0)
            ),
            corner: max(mix(corner, other.corner), 0), fusion: EdgeFusion.mix(fusion, other.fusion, amount),
            edge: progress < 0.5 ? edge : other.edge, kind: progress < 0.5 ? kind : other.kind
        )
    }
}

/// The panel's outline: a rounded rectangle, or, where it is fused with the screen edge, the liquid outline of that
/// rectangle joined to the edge (`LiquidField`), traced fresh for each frame.
struct PanelShape: Shape {
    var spec: ShapeSpec

    func path(in bounds: CGRect) -> Path {
        guard let fusion = spec.fusion, fusion.reach > Tokens.Liquid.minimumReach else {
            return RoundedRectangle(cornerRadius: spec.corner, style: .continuous).path(in: spec.rect)
        }
        // As it fuses, the box reaches past the edge by its corner, so its corners on that side go off screen and the
        // edge meets its straight sides, where the fillets form.
        let past = spec.corner * min(fusion.reach / Tokens.Dock.flareRadius, 1)
        var box = spec.rect
        box.size.width += past
        if fusion.edge == .left { box.origin.x -= past }
        // The union reaches half its `k` where the box's sides meet the edge at a right angle.
        let k = fusion.reach * 2
        let pad = k * 1.25 + Tokens.Liquid.step * 2
        var region = box.insetBy(dx: -pad, dy: -pad)
        region = region.union(CGRect(x: fusion.x - pad, y: region.minY, width: pad * 2, height: region.height))
        let step = max(Tokens.Liquid.step, (region.width * region.height / Tokens.Liquid.maximumCells).squareRoot())
        let corner = spec.corner
        return ContourTracer.path(region: region, step: step) { p in
            LiquidField.union(
                LiquidField.beyondEdge(p, x: fusion.x, edge: fusion.edge), LiquidField.roundedBox(p, box, corner: corner), k: k
            ).distance
        }
    }
}
