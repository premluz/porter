import CoreGraphics
import Testing
@testable import PorterMacKit

@Suite("Edge geometry")
struct GeometryTests {
    private let screen = CGRect(x: 0, y: 25, width: 1440, height: 850)

    @Test("the capsule hugs the chosen edge with a margin, on both sides")
    func capsuleEdges() {
        let right = EdgeGeometry.capsuleFrame(in: screen, edge: .right, anchor: 0.5, dotCount: 3, hasOverflow: false)
        let left = EdgeGeometry.capsuleFrame(in: screen, edge: .left, anchor: 0.5, dotCount: 3, hasOverflow: false)
        #expect(right.maxX == screen.maxX - Tokens.Size.edgeMargin)
        #expect(left.minX == screen.minX + Tokens.Size.edgeMargin)
        #expect(right.width == Tokens.Size.capsuleWidth)
    }

    @Test("the capsule grows with dots but never past the cap, and never wall-height")
    func capsuleHeight() {
        func height(_ dots: Int, overflow: Bool = false) -> CGFloat {
            EdgeGeometry.capsuleFrame(in: screen, edge: .right, anchor: 0.5, dotCount: dots, hasOverflow: overflow).height
        }
        #expect(height(0) < height(1))
        #expect(height(1) < height(Tokens.Capsule.maximumDots))
        #expect(height(50) == height(Tokens.Capsule.maximumDots))
        #expect(height(6, overflow: true) > height(6))
        #expect(height(50, overflow: true) < screen.height / 2)
    }

    @Test("an anchor near either end is pulled back inside the visible screen")
    func anchorClamped() {
        for anchor in [-1.0, 0, 0.01, 0.99, 1, 2] {
            let frame = EdgeGeometry.paneFrame(in: screen, edge: .right, anchor: anchor, rowCount: 6, sectionCount: 2)
            #expect(frame.minY >= screen.minY + Tokens.Size.edgeMargin, "anchor \(anchor)")
            #expect(frame.maxY <= screen.maxY - Tokens.Size.edgeMargin, "anchor \(anchor)")
        }
    }

    @Test("the pane fits its rows, has a minimum, and is capped to the visible height")
    func paneHeight() {
        let few = EdgeGeometry.paneFrame(in: screen, edge: .right, anchor: 0.5, rowCount: 1, sectionCount: 1)
        let many = EdgeGeometry.paneFrame(in: screen, edge: .right, anchor: 0.5, rowCount: 500, sectionCount: 2)
        let none = EdgeGeometry.paneFrame(in: screen, edge: .right, anchor: 0.5, rowCount: 0, sectionCount: 0)
        #expect(none.height == Tokens.Size.minimumPaneHeight)
        #expect(few.height >= Tokens.Size.minimumPaneHeight)
        #expect(many.height == screen.height - 2 * Tokens.Size.edgeMargin)
        #expect(many.width == Tokens.Size.paneWidth)
    }

    @Test("a short screen caps the capsule too, and a second display at an offset still works")
    func smallAndOffsetScreens() {
        let tiny = CGRect(x: 1440, y: -200, width: 800, height: 100)
        let capsule = EdgeGeometry.capsuleFrame(in: tiny, edge: .left, anchor: 0.5, dotCount: 6, hasOverflow: true)
        #expect(tiny.insetBy(dx: 0, dy: Tokens.Size.edgeMargin).contains(capsule))
        #expect(capsule.minX == tiny.minX + Tokens.Size.edgeMargin)
        let offset = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let pane = EdgeGeometry.paneFrame(in: offset, edge: .right, anchor: 0.3, rowCount: 4, sectionCount: 2)
        #expect(pane.maxX == offset.maxX - Tokens.Size.edgeMargin)
        #expect(offset.contains(pane))
    }

    @Test("frames are whole points and stay inside a screen with fractional bounds")
    func wholePoints() {
        let fractional = CGRect(x: 0.5, y: 25.5, width: 1440.5, height: 850.5)
        for edge in PanelEdge.allCases {
            for anchor in [0.0, 0.3, 0.5, 0.77, 1.0] {
                let frames = [
                    EdgeGeometry.capsuleFrame(in: fractional, edge: edge, anchor: anchor, dotCount: 4, hasOverflow: false),
                    EdgeGeometry.paneFrame(in: fractional, edge: edge, anchor: anchor, rowCount: 5, sectionCount: 2),
                ]
                for frame in frames {
                    #expect(frame.origin.x == frame.origin.x.rounded() && frame.origin.y == frame.origin.y.rounded())
                    #expect(frame.height == frame.height.rounded() && frame.width == frame.width.rounded())
                    #expect(fractional.contains(frame), "\(edge) \(anchor) \(frame)")
                }
            }
        }
    }

    @Test("a screen rectangle becomes top-left window coordinates, so SwiftUI places it where AppKit does")
    func localRects() {
        let window = CGRect(x: 1000, y: 100, width: 360, height: 600)
        let capsule = CGRect(x: 1320, y: 300, width: 40, height: 200)
        let local = EdgeGeometry.localRect(of: capsule, in: window)
        #expect(local == CGRect(x: 320, y: 200, width: 40, height: 200))
        #expect(EdgeGeometry.localRect(of: window, in: window) == CGRect(x: 0, y: 0, width: 360, height: 600))
        #expect(EdgeGeometry.localRect(of: capsule, in: capsule) == CGRect(x: 0, y: 0, width: 40, height: 200))
    }

    @Test("the capsule sits inside the pane window at the same screen position, so opening does not move it")
    func capsuleInsidePaneWindow() {
        for edge in PanelEdge.allCases {
            let capsule = EdgeGeometry.capsuleFrame(in: screen, edge: edge, anchor: 0.4, dotCount: 4, hasOverflow: false)
            let pane = EdgeGeometry.paneFrame(in: screen, edge: edge, anchor: 0.4, rowCount: 6, sectionCount: 2)
            let local = EdgeGeometry.localRect(of: capsule, in: pane)
            #expect(CGRect(origin: .zero, size: pane.size).contains(local), "\(edge)")
            #expect(local.minX + pane.minX == capsule.minX && pane.maxY - local.maxY == capsule.minY)
        }
    }
}

struct NoAnimationStarted: Error {}

private extension PanelStateMachine {
    mutating func requireOpen() throws -> PanelAnimation {
        guard let animation = open() else { throw NoAnimationStarted() }
        return animation
    }

    mutating func requireClose() throws -> PanelAnimation {
        guard let animation = close() else { throw NoAnimationStarted() }
        return animation
    }
}

@Suite("Open and close with reversal")
struct StateMachineTests {
    @Test("opening and closing complete in order")
    func normalCycle() throws {
        var machine = PanelStateMachine()
        let open = try machine.requireOpen()
        #expect(machine.phase == .expanding)
        let doneOpen = machine.finished(open)
        #expect(doneOpen)
        #expect(machine.phase == .expanded)
        let close = try machine.requireClose()
        #expect(machine.phase == .collapsing)
        let doneClose = machine.finished(close)
        #expect(doneClose)
        #expect(machine.phase == .collapsed)
    }

    @Test("repeating the same request does nothing")
    func idempotent() throws {
        var machine = PanelStateMachine()
        _ = try machine.requireOpen()
        let second = machine.open()
        #expect(second == nil)
        var closed = PanelStateMachine()
        let none = closed.close()
        #expect(none == nil)
    }

    @Test("closing mid-open reverses, and the interrupted open's completion is ignored")
    func reversalIgnoresStaleCompletion() throws {
        var machine = PanelStateMachine()
        let open = try machine.requireOpen()
        let close = try machine.requireClose()
        #expect(machine.phase == .collapsing)
        let doneOpen = machine.finished(open)
        #expect(!doneOpen)
        #expect(machine.phase == .collapsing)
        let doneClose = machine.finished(close)
        #expect(doneClose)
        #expect(machine.phase == .collapsed)
    }

    @Test("opening mid-close reverses the other way")
    func reopenMidClose() throws {
        var machine = PanelStateMachine()
        let open = try machine.requireOpen()
        machine.finished(open)
        let close = try machine.requireClose()
        let reopen = try machine.requireOpen()
        let doneClose = machine.finished(close)
        #expect(!doneClose)
        let doneReopen = machine.finished(reopen)
        #expect(doneReopen)
        #expect(machine.phase == .expanded)
    }

    @Test("rapid toggling always ends in the state of the last request")
    func rapidToggle() throws {
        var machine = PanelStateMachine()
        var animations: [PanelAnimation] = []
        for _ in 0..<7 { if let next = machine.toggle() { animations.append(next) } }
        for animation in animations { machine.finished(animation) }
        #expect(machine.phase == .expanded)
    }
}
