import CoreGraphics
import Foundation
import Testing
@testable import PorterMacKit

@Suite("Where each combination of rest state puts the panel's shapes")
struct PanelLayoutTests {
    private let screen = CGRect(x: 0, y: 40, width: 1_440, height: 860)

    @Test("docked, the resting shape is the tab and the window is the tab with its flares; peeking, it is the edge capsule")
    func docked() {
        var layout = PanelLayout(mode: .docked, edge: .right, dotCount: 4, markCount: 2)
        let tab = layout.restFrame(in: screen)
        #expect(layout.restIsTab && tab.width == Tokens.Dock.tabDepth && tab.maxX == screen.maxX)
        #expect(layout.restWindow(in: screen) == DockGeometry.tabWindowFrame(tab))
        layout.peeking = true
        #expect(!layout.restIsTab && layout.restFrame(in: screen).width == Tokens.Size.capsuleWidth)
        #expect(layout.restWindow(in: screen) == layout.restFrame(in: screen))
    }

    @Test("floating, the resting shape is the capsule where it was left, in the orientation it has")
    func floating() {
        var layout = PanelLayout(mode: .floating, floatCenter: CGPoint(x: 0.4, y: 0.5), orientation: .vertical, dotCount: 5)
        let upright = layout.restFrame(in: screen)
        layout.orientation = .horizontal
        let lying = layout.restFrame(in: screen)
        #expect(upright.width == Tokens.Size.capsuleWidth && lying.height == Tokens.Size.capsuleWidth && upright.height == lying.width)
        #expect(!layout.restIsTab)
    }

    @Test("the open pane sits at the docked edge, or level with a floating capsule on the side with more room")
    func pane() {
        let docked = PanelLayout(mode: .docked, edge: .right, rowCount: 6, sectionCount: 2).paneFrame(in: screen)
        #expect(docked.maxX == screen.maxX - Tokens.Size.edgeMargin)
        let layout = PanelLayout(mode: .floating, floatCenter: CGPoint(x: 0.8, y: 0.5), dotCount: 4, rowCount: 6, sectionCount: 2)
        let capsule = layout.restFrame(in: screen)
        let floating = layout.paneFrame(in: screen)
        #expect(floating.maxX == capsule.maxX && layout.paneEdge(in: screen) == .right)
        #expect(PanelLayout(mode: .floating, floatCenter: CGPoint(x: 0.1, y: 0.5), dotCount: 4).paneEdge(in: screen) == .left)
    }

    @Test("the shape specs are in the window's own coordinates and carry the flare only for the tab")
    func specs() {
        let layout = PanelLayout(mode: .docked, edge: .right, dotCount: 4, markCount: 2)
        let window = layout.restWindow(in: screen)
        let rest = layout.restSpec(in: window, screen: screen)
        #expect(rest.kind == .tab && rest.flare == Tokens.Dock.flareRadius && rest.rect.minY == Tokens.Dock.flareRadius)
        var peek = layout
        peek.peeking = true
        let capsule = peek.restSpec(in: peek.restWindow(in: screen), screen: screen)
        #expect(capsule.kind == .capsule(.vertical) && capsule.flare == 0 && capsule.rect.origin == .zero)
        #expect(layout.paneSpec(in: layout.paneFrame(in: screen), screen: screen).rect.origin == .zero)
    }
}
