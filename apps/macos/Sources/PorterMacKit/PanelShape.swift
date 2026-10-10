import CoreGraphics
import SwiftUI

public enum ShapeKind: Sendable, Equatable {
    case tab
    case capsule(PanelOrientation)
    case pane
}

/// One shape the panel can be: where it is in the window (top-left coordinates), how round, and, for the docked tab,
/// how far it flares out along the screen edge. The panel is always a single shape moving between these.
public struct ShapeSpec: Sendable, Equatable {
    public var rect: CGRect
    public var corner: CGFloat
    /// The radius of the concave curve on each side of the tab where it meets the edge; 0 for everything else.
    public var flare: CGFloat
    public var edge: PanelEdge
    public var kind: ShapeKind

    public init(rect: CGRect, corner: CGFloat, flare: CGFloat = 0, edge: PanelEdge, kind: ShapeKind) {
        self.rect = rect
        self.corner = corner
        self.flare = flare
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
            corner: max(mix(corner, other.corner), 0), flare: max(mix(flare, other.flare), 0),
            edge: progress < 0.5 ? edge : other.edge, kind: progress < 0.5 ? kind : other.kind
        )
    }
}

/// The panel's outline: a rounded rectangle, and where the spec has a flare, a concave curve on each side of it that
/// runs out along the screen edge, so a docked tab seems to grow out of the edge.
struct PanelShape: Shape {
    var spec: ShapeSpec

    func path(in bounds: CGRect) -> Path {
        let body = RoundedRectangle(cornerRadius: spec.corner, style: .continuous).path(in: spec.rect)
        guard spec.flare > 0.5 else { return body }
        var path = body
        let f = min(spec.flare, spec.rect.height / 2)
        let k = f * Self.circleControl
        let rect = spec.rect
        // The side of the tab that lies on the screen edge, and the direction the flares open away from the tab.
        let base = spec.edge == .right ? rect.maxX : rect.minX
        let inward: CGFloat = spec.edge == .right ? -1 : 1
        for (y, outward) in [(rect.minY, CGFloat(-1)), (rect.maxY, CGFloat(1))] {
            var curve = Path()
            curve.move(to: CGPoint(x: base, y: y + outward * f))
            curve.addLine(to: CGPoint(x: base, y: y))
            curve.addLine(to: CGPoint(x: base + inward * f, y: y))
            curve.addCurve(
                to: CGPoint(x: base, y: y + outward * f),
                control1: CGPoint(x: base + inward * (f - k), y: y), control2: CGPoint(x: base, y: y + outward * (f - k))
            )
            curve.closeSubpath()
            // Joined into one outline, so the seams between the flares and the body are not part of the edge.
            path = path.union(curve)
        }
        return path
    }

    /// The control distance that makes a cubic curve follow a quarter circle.
    private static let circleControl: CGFloat = 0.5523
}
