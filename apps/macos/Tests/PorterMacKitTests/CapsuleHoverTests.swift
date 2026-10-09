import CoreGraphics
import Foundation
import Testing
@testable import PorterMacKit

@Suite("Hovering a dot in the collapsed capsule")
struct CapsuleHoverTests {
    private let frames: [String: CGRect] = [
        "a": CGRect(x: 7, y: 60, width: 26, height: 26),
        "b": CGRect(x: 7, y: 90, width: 26, height: 26),
    ]

    @Test("the pointer picks the dot it is over, and the gap between two dots belongs to one of them")
    func hitTest() {
        #expect(CapsuleHover.item(at: CGPoint(x: 20, y: 70), frames: frames) == "a")
        #expect(CapsuleHover.item(at: CGPoint(x: 20, y: 100), frames: frames) == "b")
        let gap = CGPoint(x: 20, y: 88)
        #expect(["a", "b"].contains(CapsuleHover.item(at: gap, frames: frames) ?? ""))
        #expect(CapsuleHover.item(at: CGPoint(x: 20, y: 10), frames: frames) == nil)
        #expect(CapsuleHover.item(at: CGPoint(x: 20, y: 70), frames: [:]) == nil)
    }

    @Test("the open button is hit like a dot, so it shows the pointing hand too, and dots below it are still reachable")
    func openButton() {
        var all = frames
        all[PanelPresentation.openButtonId] = CGRect(x: 6, y: 12, width: 28, height: 28)
        #expect(CapsuleHover.item(at: CGPoint(x: 20, y: 26), frames: all) == PanelPresentation.openButtonId)
        #expect(CapsuleHover.item(at: CGPoint(x: 20, y: 70), frames: all) == "a")
    }

    @Test("a dot's frame in the window becomes a rectangle on screen, with the y axis turned over")
    func screenRect() {
        let window = CGRect(x: 1_400, y: 300, width: 40, height: 244)
        let rect = CapsuleHover.screenRect(of: frames["a"] ?? .zero, inWindow: window)
        #expect(rect == CGRect(x: 1_407, y: 300 + 244 - 86, width: 26, height: 26))
    }

    @Test("the label sits on the screen side of the capsule, level with its dot, and never leaves the screen")
    func labelFrame() {
        let visible = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let window = CGRect(x: 1_400, y: 300, width: 40, height: 244)
        let anchor = CGRect(x: 1_407, y: 458, width: 26, height: 26)
        let size = CGSize(width: 200, height: 50)
        let right = CapsuleHover.tooltipFrame(anchor: anchor, size: size, window: window, edge: .right, visible: visible)
        #expect(right.maxX <= window.minX && right.midY == anchor.midY)
        let left = CapsuleHover.tooltipFrame(anchor: anchor, size: size, window: CGRect(x: 0, y: 300, width: 40, height: 244), edge: .left, visible: visible)
        #expect(left.minX >= 40)
        let high = CapsuleHover.tooltipFrame(anchor: CGRect(x: 1_407, y: 895, width: 26, height: 26), size: size, window: window, edge: .right, visible: visible)
        #expect(high.maxY <= visible.maxY && high.minY >= visible.minY)
        let low = CapsuleHover.tooltipFrame(anchor: CGRect(x: 1_407, y: -5, width: 26, height: 26), size: size, window: window, edge: .right, visible: visible)
        #expect(low.minY >= visible.minY)
    }
}
