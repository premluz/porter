import AppKit
import SwiftUI

/// A hosting view that reports where the pointer is, in top-left coordinates, whether or not the app or window is
/// active. The panel never is, and SwiftUI's own hover is not delivered to an inactive window.
final class TrackingHostingView<Content: View>: NSHostingView<Content> {
    /// The pointer's position, or nil when it left the view.
    var onPointer: ((CGPoint?) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self, userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { report(event) }
    override func mouseMoved(with event: NSEvent) { report(event) }
    override func mouseExited(with event: NSEvent) { onPointer?(nil) }

    private func report(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onPointer?(isFlipped ? point : CGPoint(x: point.x, y: bounds.height - point.y))
    }
}
