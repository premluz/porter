import ConversationCore
import PorterPanelModel
import Testing
@testable import PorterMacKit

@Suite("The docked tab's mascot")
struct MascotTests {
    @Test("the eyes look towards the middle of the screen from either edge")
    func gaze() {
        #expect(MascotView.gaze(opensFrom: .right) < 0)
        #expect(MascotView.gaze(opensFrom: .left) > 0)
    }

    @Test("a question is orange and outranks work, which is green, and everything else is gray")
    func tone() {
        func status(_ display: DisplayStatus) -> ItemStatus { ItemStatus(display: display, freshness: .fresh, ageSeconds: 3) }
        #expect(MascotTone(status(.needsUser)) == .attention)
        #expect(MascotTone(status(.working)) == .working)
        #expect(MascotTone(status(.idle)) == .quiet && MascotTone(status(.newResponse)) == .quiet)
        #expect(MascotTone(nil) == .quiet)
        #expect(MascotTone.attention.color != MascotTone.working.color && MascotTone.working.color != MascotTone.quiet.color)
    }

    @Test("the body fits inside the tab with room around it, and the eyes fit inside the body")
    func fits() {
        #expect(Tokens.Mascot.size < Tokens.Dock.tabDepth)
        #expect(Tokens.Mascot.size < DockGeometry.tabSize.height)
        let eyes = Tokens.Mascot.eyeWidth * 2 + Tokens.Mascot.eyeGap + Tokens.Mascot.gaze * 2
        #expect(eyes < Tokens.Mascot.size)
        #expect(Tokens.Mascot.eyeHeight + Tokens.Mascot.eyeLift * 2 < Tokens.Mascot.size)
    }
}
