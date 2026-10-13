import Foundation
import Testing
@testable import NativeSources

@Suite("The control probe")
struct ControlProbeTests {
    @Test("only buttons outside the sidebar strip count, and labels are cut short")
    func controls() {
        let window = FakeNode("AXWindow", "", frame: CGRect(x: 100, y: 0, width: 800, height: 600), children: [
            FakeNode("AXButton", "In the sidebar", frame: CGRect(x: 110, y: 10, width: 80, height: 20)),
            FakeNode("AXStaticText", "Message text", frame: CGRect(x: 500, y: 10, width: 80, height: 20)),
            FakeNode("AXButton", "Stop", frame: CGRect(x: 800, y: 500, width: 30, height: 30)),
            FakeNode("AXButton", String(repeating: "x", count: 90), frame: CGRect(x: 600, y: 500, width: 30, height: 30)),
        ])
        let found = ControlProbe.controls(in: window, stripWidth: 300)
        #expect(found.contains("AXButton Stop") && !found.contains("AXButton In the sidebar"))
        #expect(found.count == 2 && found.allSatisfy { $0.count <= "AXButton ".count + ControlProbe.labelLimit })
    }

    @Test("only controls that are not in every sample are reported")
    func changing() {
        let result = ControlProbe.changing([["AXButton Send", "AXButton Copy"], ["AXButton Stop", "AXButton Copy"], ["AXButton Stop", "AXButton Copy"]])
        #expect(result.map(\.control) == ["AXButton Send", "AXButton Stop"] && result.map(\.present) == [1, 2])
        #expect(ControlProbe.changing([]).isEmpty)
    }
}
