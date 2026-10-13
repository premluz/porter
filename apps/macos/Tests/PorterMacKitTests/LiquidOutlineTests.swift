import CoreGraphics
import SwiftUI
import Testing
@testable import PorterMacKit

@Suite("The liquid field and its outline")
struct LiquidOutlineTests {
    private func sample(_ distance: CGFloat, _ dx: CGFloat, _ dy: CGFloat) -> FieldSample {
        FieldSample(distance: distance, gradient: CGVector(dx: dx, dy: dy))
    }

    @Test("the union reaches all of k where surfaces face each other, half at a right angle, and nothing side by side")
    func reach() {
        let k: CGFloat = 8
        #expect(abs(LiquidField.union(sample(0, 1, 0), sample(0, -1, 0), k: k).distance + k / 4) < 0.01)
        #expect(abs(LiquidField.union(sample(0, -1, 0), sample(0, 0, -1), k: k).distance + k / 8) < 0.01)
        #expect(abs(LiquidField.union(sample(0, 1, 0), sample(0, 1, 0), k: k).distance) < 0.01)
        #expect(LiquidField.union(sample(12, 1, 0), sample(-3, -1, 0), k: k).distance == -3)
    }

    @Test("a rounded box is negative inside, zero on its side, and as far as the corner's arc outside a corner")
    func box() {
        let box = CGRect(x: 0, y: 0, width: 40, height: 20)
        #expect(LiquidField.roundedBox(CGPoint(x: 20, y: 10), box, corner: 5).distance < 0)
        #expect(abs(LiquidField.roundedBox(CGPoint(x: 40, y: 10), box, corner: 5).distance) < 1e-9)
        let outside = LiquidField.roundedBox(CGPoint(x: 45, y: -5), box, corner: 5)
        #expect(abs(outside.distance - (50.0.squareRoot() * 2 - 5)) < 1e-6 && outside.gradient.dx > 0 && outside.gradient.dy < 0)
    }

    @Test("a traced circle is one closed outline that matches the circle to well under a point")
    func circle() {
        let centre = CGPoint(x: 30, y: 30)
        let path = ContourTracer.path(region: CGRect(x: 0, y: 0, width: 60, height: 60), step: 1) { p in
            ((p.x - centre.x) * (p.x - centre.x) + (p.y - centre.y) * (p.y - centre.y)).squareRoot() - 20
        }
        var moves = 0
        path.forEach { element in if case .move = element { moves += 1 } }
        #expect(moves == 1)
        let bounds = path.boundingRect
        #expect(abs(bounds.minX - 10) < 0.05 && abs(bounds.maxX - 50) < 0.05 && abs(bounds.height - 40) < 0.1)
        #expect(path.contains(centre) && !path.contains(CGPoint(x: 1, y: 1)))
    }

    @Test("two separate blobs are two outlines, and a region too small to trace gives nothing")
    func separate() {
        let path = ContourTracer.path(region: CGRect(x: 0, y: 0, width: 80, height: 20), step: 1) { p in
            min(abs(p.x - 20), abs(p.x - 60)) - 6
        }
        var moves = 0
        path.forEach { element in if case .move = element { moves += 1 } }
        #expect(moves == 2)
        #expect(ContourTracer.path(region: CGRect(x: 0, y: 0, width: 1, height: 1), step: 1) { _ in -1 }.isEmpty)
    }
}
