import CoreGraphics
import SwiftUI
import Testing
@testable import PorterMacKit

@Suite("The one outline the panel is drawn with")
struct PanelShapeTests {
    private let reach = Tokens.Dock.flareRadius

    private func tab(edge: PanelEdge) -> ShapeSpec {
        let rect = edge == .right ? CGRect(x: 40, y: 60, width: 22, height: 56) : CGRect(x: 0, y: 60, width: 22, height: 56)
        let fusion = EdgeFusion(edge: edge, x: edge == .right ? 62 : 0, reach: reach)
        return ShapeSpec(rect: rect, corner: Tokens.Dock.tabCorner, fusion: fusion, edge: edge, kind: .tab)
    }

    private func contours(_ path: Path) -> Int {
        var count = 0
        path.forEach { element in if case .move = element { count += 1 } }
        return count
    }

    @Test("with no fusion it is the rounded rectangle")
    func plain() {
        let plain = PanelShape(spec: ShapeSpec(rect: CGRect(x: 10, y: 10, width: 40, height: 100), corner: 20, edge: .right, kind: .capsule(.vertical)))
        #expect(plain.path(in: .zero).boundingRect == CGRect(x: 10, y: 10, width: 40, height: 100))
    }

    @Test("where the tab meets the edge a fillet runs along it as far as its reach, hollow away from the corner, on either edge")
    func fillet() {
        for edge in [PanelEdge.right, .left] {
            let spec = tab(edge: edge)
            let path = PanelShape(spec: spec).path(in: .zero)
            let base = edge == .right ? spec.rect.maxX : spec.rect.minX
            let toward: CGFloat = edge == .right ? -1 : 1
            for (y, outward) in [(spec.rect.minY, CGFloat(-1)), (spec.rect.maxY, CGFloat(1))] {
                #expect(path.contains(CGPoint(x: base + toward, y: y + outward)))
                #expect(path.contains(CGPoint(x: base + toward * 0.5, y: y + outward * reach / 2)))
                #expect(!path.contains(CGPoint(x: base + toward * 0.5, y: y + outward * (reach + 2))))
                #expect(!path.contains(CGPoint(x: base + toward * reach, y: y + outward * reach)))
            }
            #expect(path.contains(CGPoint(x: spec.rect.midX, y: spec.rect.midY)))
        }
    }

    @Test("the docked tab is one outline with no seams, square where it meets the edge and round on the side facing the screen")
    func oneOutline() {
        for edge in [PanelEdge.right, .left] {
            let spec = tab(edge: edge)
            let path = PanelShape(spec: spec).path(in: .zero)
            #expect(contours(path) == 1)
            let base = edge == .right ? spec.rect.maxX : spec.rect.minX
            let far = edge == .right ? spec.rect.minX : spec.rect.maxX
            let toward: CGFloat = edge == .right ? -1 : 1
            #expect(path.contains(CGPoint(x: base + toward * 0.5, y: spec.rect.minY + 0.5)))
            #expect(!path.contains(CGPoint(x: far - toward * 0.5, y: spec.rect.minY + 0.5)))
        }
    }

    @Test("folding a capsule into the tab never opens a gap: the body stays whole, and once it touches the edge it is joined to it")
    func noGapWhileFolding() {
        let docked = tab(edge: .right)
        let capsule = ShapeSpec(rect: CGRect(x: 22, y: 40, width: 32, height: 96), corner: 16, edge: .right, kind: .capsule(.vertical))
        for step in 0...20 {
            let spec = capsule.blended(toward: docked, Double(step) / 20)
            let path = PanelShape(spec: spec).path(in: .zero)
            let inner = spec.rect.insetBy(dx: spec.corner / 2 + 1, dy: spec.corner / 2 + 1)
            for fx in [0.0, 0.5, 1.0] {
                for fy in [0.0, 0.25, 0.5, 0.75, 1.0] {
                    #expect(path.contains(CGPoint(x: inner.minX + inner.width * fx, y: inner.minY + inner.height * fy)))
                }
            }
            if spec.rect.maxX >= 61.5 {
                #expect(path.contains(CGPoint(x: 61.5, y: spec.rect.midY)))
            }
        }
    }

    @Test("moving between two shapes keeps a bounce, never goes negative, changes kind halfway and fuses gradually")
    func blending() {
        let capsule = ShapeSpec(rect: CGRect(x: 0, y: 0, width: 40, height: 200), corner: 20, edge: .right, kind: .capsule(.vertical))
        let pane = ShapeSpec(rect: CGRect(x: -320, y: 0, width: 360, height: 400), corner: 28, edge: .right, kind: .pane)
        #expect(capsule.blended(toward: pane, 0) == capsule && capsule.blended(toward: pane, 1) == pane)
        #expect(capsule.blended(toward: pane, 1.1).rect.width > 360)
        #expect(capsule.blended(toward: pane, -5).rect.width >= 0)
        #expect(capsule.blended(toward: pane, 0.4).kind == .capsule(.vertical) && capsule.blended(toward: pane, 0.6).kind == .pane)
        let halfway = capsule.blended(toward: tab(edge: .right), 0.5).fusion
        #expect(halfway?.reach == reach / 2 && halfway?.edge == .right)
        let across = EdgeFusion.mix(tab(edge: .right).fusion, tab(edge: .left).fusion, 0.25)
        #expect(across?.edge == .right && across?.reach == reach / 2)
        #expect(EdgeFusion.mix(tab(edge: .right).fusion, tab(edge: .left).fusion, 0.75)?.edge == .left)
    }
}
