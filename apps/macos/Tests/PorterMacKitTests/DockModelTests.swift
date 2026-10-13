import CoreGraphics
import Foundation
import Testing
@testable import PorterMacKit

@Suite("The geometry of the docked, floating and open states")
struct DockModelTests {
    private let screen = CGRect(x: 0, y: 40, width: 1_440, height: 860)

    @Test("the capsule is as long as its dots need in either orientation, and the docked tab has room for its mark")
    func sizes() {
        let tall = DockGeometry.capsuleSize(orientation: .vertical, dotCount: 4, hasOverflow: false)
        let wide = DockGeometry.capsuleSize(orientation: .horizontal, dotCount: 4, hasOverflow: false)
        #expect(tall.width == Tokens.Size.capsuleWidth && wide.height == Tokens.Size.capsuleWidth && tall.height == wide.width)
        #expect(DockGeometry.capsuleSize(orientation: .vertical, dotCount: 99, hasOverflow: true).height > tall.height)
        #expect(DockGeometry.tabSize.width == Tokens.Dock.tabDepth && DockGeometry.tabSize.height >= Tokens.Mascot.size)
    }

    @Test("a docked tab is flush with its edge, centred on its anchor, and its flares stay on the screen")
    func tab() {
        let right = DockGeometry.tabFrame(edge: .right, anchor: 0.5, in: screen)
        #expect(right.maxX == screen.maxX && right.width == Tokens.Dock.tabDepth)
        #expect(abs(right.midY - screen.midY) <= 1)
        #expect(DockGeometry.tabFrame(edge: .left, anchor: 0.5, in: screen).minX == screen.minX)
        let top = DockGeometry.tabFrame(edge: .right, anchor: 0, in: screen)
        let bottom = DockGeometry.tabFrame(edge: .right, anchor: 1, in: screen)
        let topWindow = DockGeometry.tabWindowFrame(top), bottomWindow = DockGeometry.tabWindowFrame(bottom)
        #expect(topWindow.maxY <= screen.maxY && bottomWindow.minY >= screen.minY)
    }

    @Test("the capsule at an edge is where the panel has always been, with its margin")
    func edgeCapsule() {
        let size = DockGeometry.capsuleSize(orientation: .vertical, dotCount: 3, hasOverflow: false)
        let frame = DockGeometry.edgeCapsuleFrame(edge: .right, anchor: 0.5, size: size, in: screen)
        #expect(frame.maxX == screen.maxX - Tokens.Size.edgeMargin && frame.size == size)
    }

    @Test("a floating capsule is centred where it was left and kept inside the screen")
    func floating() {
        let middle = DockGeometry.floatingFrame(center: CGPoint(x: 0.5, y: 0.5), orientation: .vertical, dotCount: 4, hasOverflow: false, in: screen)
        #expect(abs(middle.midX - screen.midX) <= 1 && abs(middle.midY - screen.midY) <= 1)
        for corner in [CGPoint(x: -1, y: -1), CGPoint(x: 2, y: 2), CGPoint(x: 0, y: 1)] {
            let frame = DockGeometry.floatingFrame(center: corner, orientation: .horizontal, dotCount: 4, hasOverflow: false, in: screen)
            #expect(screen.insetBy(dx: Tokens.Size.edgeMargin - 1, dy: Tokens.Size.edgeMargin - 1).contains(frame))
        }
    }

    @Test("near the top or bottom the capsule lies down; once down it needs extra room to stand up again")
    func orientation() {
        func decide(_ y: CGFloat, _ current: PanelOrientation) -> PanelOrientation {
            DockGeometry.orientation(center: CGPoint(x: 0.5, y: y), current: current, dotCount: 6, hasOverflow: false, in: screen)
        }
        #expect(decide(0.5, .vertical) == .vertical)
        #expect(decide(0.01, .vertical) == .horizontal && decide(0.99, .vertical) == .horizontal)
        // A place where the upright capsule only just fits: it stays upright if it is, and stays lying if it is not.
        let height = DockGeometry.capsuleSize(orientation: .vertical, dotCount: 6, hasOverflow: false).height
        let edgeY = (height / 2 + Tokens.Size.edgeMargin + 4) / screen.height
        #expect(decide(edgeY, .vertical) == .vertical && decide(edgeY, .horizontal) == .horizontal)
        let tiny = CGRect(x: 0, y: 0, width: 800, height: 200)
        #expect(DockGeometry.orientation(center: CGPoint(x: 0.5, y: 0.5), current: .vertical, dotCount: 6, hasOverflow: false, in: tiny) == .horizontal)
    }

    @Test("released near an edge it docks at the height it was released; elsewhere it stays where it is")
    func snap() {
        #expect(DockGeometry.snap(dragCenter: CGPoint(x: screen.maxX - 20, y: screen.midY), in: screen) == .dock(edge: .right, anchor: 0.5))
        #expect(DockGeometry.snap(dragCenter: CGPoint(x: screen.minX + 30, y: screen.maxY - screen.height * 0.25), in: screen) == .dock(edge: .left, anchor: 0.25))
        guard case .float(let center) = DockGeometry.snap(dragCenter: CGPoint(x: 600, y: screen.midY), in: screen) else { Issue.record("expected float"); return }
        #expect(abs(center.x - 600 / 1_440) < 0.001 && abs(center.y - 0.5) < 0.001)
        #expect(DockGeometry.snap(dragCenter: CGPoint(x: screen.maxX - Tokens.Dock.snapDistance - 1, y: 400), in: screen) != .dock(edge: .right, anchor: 0.5))
    }

    @Test("the pull grows as the capsule nears an edge, reaches the resting place there and is nothing beyond its range")
    func magnet() {
        let resting: (PanelEdge) -> CGFloat = { $0 == .right ? screen.maxX - 28 : screen.minX + 28 }
        let far = DockGeometry.magnet(dragCenter: CGPoint(x: 700, y: 400), restingCenterX: resting, in: screen)
        #expect(far.strength == 0 && far.center.x == 700)
        var previous: CGFloat = -1
        for distance in stride(from: Tokens.Dock.pullDistance - 1, through: 1, by: -10) {
            let pulled = DockGeometry.magnet(dragCenter: CGPoint(x: screen.maxX - distance, y: 400), restingCenterX: resting, in: screen)
            let low = min(screen.maxX - distance, resting(.right)), high = max(screen.maxX - distance, resting(.right))
            #expect(pulled.strength >= previous && (low...high).contains(pulled.center.x))
            previous = pulled.strength
        }
        let atEdge = DockGeometry.magnet(dragCenter: CGPoint(x: screen.maxX - 1, y: 400), restingCenterX: resting, in: screen)
        #expect(atEdge.strength > 0.95 && abs(atEdge.center.x - resting(.right)) < 2)
    }

    @Test("a docked tab comes away only after being dragged clear of its edge")
    func detach() {
        #expect(!DockGeometry.hasDetached(dragCenter: CGPoint(x: screen.maxX - 10, y: 400), edge: .right, in: screen))
        #expect(DockGeometry.hasDetached(dragCenter: CGPoint(x: screen.maxX - 100, y: 400), edge: .right, in: screen))
        #expect(DockGeometry.hasDetached(dragCenter: CGPoint(x: screen.minX + 100, y: 400), edge: .left, in: screen))
    }

    @Test("the pane opens level with a floating capsule on the side with more room, and stays on the screen")
    func floatingPane() {
        let pane = CGSize(width: 360, height: 464)
        let right = CGRect(x: 1_300, y: 300, width: 40, height: 244)
        let opened = DockGeometry.floatingPaneFrame(capsule: right, paneSize: pane, in: screen)
        #expect(opened.maxX == right.maxX && abs(opened.midY - right.midY) <= 1)
        let left = DockGeometry.floatingPaneFrame(capsule: CGRect(x: 100, y: 300, width: 40, height: 244), paneSize: pane, in: screen)
        #expect(left.minX == 100)
        let corner = DockGeometry.floatingPaneFrame(capsule: CGRect(x: 1_395, y: 850, width: 40, height: 40), paneSize: pane, in: screen)
        #expect(screen.contains(corner))
    }
}
