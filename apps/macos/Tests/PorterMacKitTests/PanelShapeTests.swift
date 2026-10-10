import CoreGraphics
import SwiftUI
import Testing
@testable import PorterMacKit

@Suite("The one outline the panel is drawn with")
struct PanelShapeTests {
    private func tab(edge: PanelEdge) -> ShapeSpec {
        let rect = edge == .right ? CGRect(x: 40, y: 60, width: 22, height: 56) : CGRect(x: 0, y: 60, width: 22, height: 56)
        return ShapeSpec(rect: rect, corner: 10, flare: 14, edge: edge, kind: .tab)
    }

    @Test("without a flare it is the rounded rectangle, and with one it reaches the flare's radius past the tab along the edge")
    func extent() {
        let plain = PanelShape(spec: ShapeSpec(rect: CGRect(x: 10, y: 10, width: 40, height: 100), corner: 20, edge: .right, kind: .capsule(.vertical)))
        #expect(plain.path(in: .zero).boundingRect == CGRect(x: 10, y: 10, width: 40, height: 100))
        let bounds = PanelShape(spec: tab(edge: .right)).path(in: .zero).boundingRect
        #expect(bounds.minY.rounded() == 60 - 14 && bounds.maxY.rounded() == 116 + 14 && bounds.maxX.rounded() == 62)
    }

    @Test("the flare fills the corner where the tab meets the edge and leaves the room beyond its curve empty, on either edge")
    func fillsTheCorner() {
        for edge in [PanelEdge.right, .left] {
            let spec = tab(edge: edge)
            let path = PanelShape(spec: spec).path(in: .zero)
            let base = edge == .right ? spec.rect.maxX : spec.rect.minX
            let toward: CGFloat = edge == .right ? -1 : 1
            // Hard against the edge, just beyond the tab's end: inside the flare.
            #expect(path.contains(CGPoint(x: base + toward * 1, y: spec.rect.minY - 1)))
            #expect(path.contains(CGPoint(x: base + toward * 1, y: spec.rect.maxY + 1)))
            // Away from the edge and beyond the tab's end, the middle of the curve's hollow: empty.
            #expect(!path.contains(CGPoint(x: base + toward * 12, y: spec.rect.minY - 12)))
            #expect(!path.contains(CGPoint(x: base + toward * 12, y: spec.rect.maxY + 12)))
            // The tab itself, and the space beyond the flare along the edge, are as expected.
            #expect(path.contains(CGPoint(x: spec.rect.midX, y: spec.rect.midY)))
            #expect(!path.contains(CGPoint(x: base + toward * 1, y: spec.rect.minY - 20)))
        }
    }

    @Test("moving between two shapes keeps a bounce, never goes negative, and changes kind halfway")
    func blending() {
        let capsule = ShapeSpec(rect: CGRect(x: 0, y: 0, width: 40, height: 200), corner: 20, edge: .right, kind: .capsule(.vertical))
        let pane = ShapeSpec(rect: CGRect(x: -320, y: 0, width: 360, height: 400), corner: 28, edge: .right, kind: .pane)
        #expect(capsule.blended(toward: pane, 0) == capsule && capsule.blended(toward: pane, 1) == pane)
        #expect(capsule.blended(toward: pane, 1.1).rect.width > 360)
        #expect(capsule.blended(toward: pane, -5).rect.width >= 0)
        #expect(capsule.blended(toward: pane, 0.4).kind == .capsule(.vertical) && capsule.blended(toward: pane, 0.6).kind == .pane)
        let docked = tab(edge: .right)
        #expect(capsule.blended(toward: docked, 0.5).flare == 7)
    }
}
