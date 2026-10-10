import CoreGraphics
import Foundation
import Testing
@testable import PorterMacKit

@Suite("What one move of a drag does to the resting state")
struct DockDragTests {
    private let screen = CGRect(x: 0, y: 40, width: 1_440, height: 860)
    private let restingX: (PanelEdge) -> CGFloat = { $0 == .right ? 1_420 : 20 }

    private func step(raw: CGPoint, mode: RestMode, orientation: PanelOrientation = .vertical) -> DockGeometry.DragStep {
        DockGeometry.dragStep(
            raw: raw, mode: mode, edge: .right, floatCenter: CGPoint(x: 0.5, y: 0.5), orientation: orientation,
            dotCount: 4, hasOverflow: false, restingCenterX: restingX, in: screen
        )
    }

    @Test("a docked tab that has not been pulled clear of its edge does not move")
    func dockedStaysPut() {
        let result = step(raw: CGPoint(x: screen.maxX - 4, y: 400), mode: .docked)
        #expect(!result.moved && result.mode == .docked)
    }

    @Test("pulling a docked tab clear of its edge detaches it as a standing capsule at the pointer")
    func detaches() {
        let result = step(raw: CGPoint(x: 700, y: 470), mode: .docked, orientation: .horizontal)
        #expect(result.moved && result.mode == .floating && result.orientation == .vertical)
        #expect(abs(result.floatCenter.x - (700 - screen.minX) / screen.width) < 0.001)
    }

    @Test("a floating capsule brought near an edge is pulled toward it, and left alone in open space")
    func magnetised() {
        let free = step(raw: CGPoint(x: 700, y: 470), mode: .floating)
        let near = step(raw: CGPoint(x: screen.maxX - 40, y: 470), mode: .floating)
        #expect(abs(free.floatCenter.x - 700 / screen.width) < 0.001)
        #expect(near.floatCenter.x > (screen.maxX - 40) / screen.width)
    }

    @Test("a floating capsule dragged to the top lies down, and stands up again once clear of it")
    func reflows() {
        let top = step(raw: CGPoint(x: 700, y: screen.maxY - 10), mode: .floating)
        let middle = step(raw: CGPoint(x: 700, y: screen.midY), mode: .floating, orientation: top.orientation)
        #expect(top.orientation == .horizontal && middle.orientation == .vertical)
    }
}
