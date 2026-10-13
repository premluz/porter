import AppKit
import SwiftUI
import Testing
@testable import PorterMacKit

/// Renders the real panel view at rest as the docked tab, and looks at the pixels: a face drawn off the tab, or
/// hidden behind it, leaves the tab plain black.
@MainActor
@Suite("The docked tab, as drawn")
struct DockedTabRenderTests {
    private let screen = CGRect(x: 0, y: 40, width: 1_440, height: 860)

    /// Below the eyes, which sit just above the face's centre.
    private func brightness(belowEyesOf image: NSBitmapImageRep, _ rect: CGRect, scale: CGFloat) -> CGFloat {
        let x = Int(rect.midX * scale), y = Int((rect.midY + Tokens.Mascot.size / 3) * scale)
        return image.colorAt(x: x, y: y)?.brightnessComponent ?? -1
    }

    @Test("the tab's face is drawn on the tab, on either edge")
    func faceIsOnTheTab() throws {
        for edge in [PanelEdge.right, .left] {
            let harness = try Harness(rows: [Harness.row("a")])
            let presentation = PanelPresentation()
            let layout = PanelLayout(mode: .docked, edge: edge, dotCount: 1)
            let window = layout.restWindow(in: screen)
            presentation.layout(rest: layout.restSpec(in: window, screen: screen), pane: layout.paneSpec(in: window, screen: screen))
            let view = PanelRootView(model: harness.model, presentation: presentation, expand: {}, close: {})
                .frame(width: window.width, height: window.height)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 4
            let tiff = try #require(renderer.nsImage?.tiffRepresentation)
            let rep = try #require(NSBitmapImageRep(data: tiff))
            let tab = presentation.restShape(at: Date()).rect
            #expect(brightness(belowEyesOf: rep, tab, scale: 4) > 0.3, "the face should be light on the black tab (\(edge))")
        }
    }
}
