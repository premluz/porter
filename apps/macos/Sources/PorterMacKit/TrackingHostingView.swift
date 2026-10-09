import AppKit
import SwiftUI

/// A hosting view that reports where the pointer is, in top-left coordinates, whether or not the app or window is
/// active. The panel never is, and SwiftUI's own hover is not delivered to an inactive window.
final class TrackingHostingView<Content: View>: NSHostingView<Content> {
    /// The pointer's position, or nil when it left the view.
    var onPointer: ((CGPoint?) -> Void)?
    /// The cursor to show at a point, or nil to leave the cursor to the views underneath (the search field's I-beam).
    /// Set on every move, because an inactive window's cursor is otherwise reset by the system as the pointer moves.
    var cursorAt: ((CGPoint) -> NSCursor?)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self, userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { report(event) }
    override func mouseMoved(with event: NSEvent) { report(event) }
    override func mouseExited(with event: NSEvent) { onPointer?(nil) }
    override func cursorUpdate(with event: NSEvent) { setCursor(for: event) }

    private func topLeft(_ event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        return isFlipped ? point : CGPoint(x: point.x, y: bounds.height - point.y)
    }

    private func setCursor(for event: NSEvent) {
        cursorAt?(topLeft(event))?.set()
    }

    private func report(_ event: NSEvent) {
        setCursor(for: event)
        onPointer?(topLeft(event))
    }
}
