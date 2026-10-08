import CoreGraphics
import Observation

/// What SwiftUI draws: whether the pane is shown, and where each shape sits inside the window.
/// The window is sized once for a whole move and only the shape inside it animates.
@MainActor
@Observable
public final class PanelPresentation {
    public var isExpanded = false
    /// Both rectangles in the window's top-left coordinates. Only the current one is drawn.
    public private(set) var capsule = CGRect.zero
    public private(set) var pane = CGRect.zero

    public init() {}

    public func layout(window: CGRect, capsuleFrame: CGRect, paneFrame: CGRect) {
        capsule = EdgeGeometry.localRect(of: capsuleFrame, in: window)
        pane = EdgeGeometry.localRect(of: paneFrame, in: window)
    }
}
