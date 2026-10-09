import CoreGraphics
import Foundation
import Observation

/// What SwiftUI draws: where the one glass shape sits inside the window, and how far along its move it
/// is. The window is sized once per move; the shape's progress comes from a spring computed from the
/// clock (see PanelMotion), so each frame of the move is known and testable.
@MainActor
@Observable
public final class PanelPresentation {
    /// The state the move is heading for.
    public private(set) var isExpanded = false
    public private(set) var isMoving = false
    public private(set) var motion = MotionState(curve: SpringCurve(duration: Tokens.Motion.springDuration, bounce: Tokens.Motion.springBounce))
    public var edge: PanelEdge = .right
    /// Where each dot of the collapsed capsule is, by item id, in the window's top-left coordinates. Written by the
    /// capsule as it lays out and read when the pointer moves, so it does not drive any redraw itself.
    @ObservationIgnored public var dotFrames: [String: CGRect] = [:]
    public static let coordinateSpace = "panel"
    /// Attached only by the animation probe, to see each frame of a move.
    @ObservationIgnored public var recorder: (@Sendable (CGRect) -> Void)?
    /// Both rectangles in the window's top-left coordinates; the shape moves between them.
    public private(set) var capsule = CGRect.zero
    public private(set) var pane = CGRect.zero

    public init() {}

    public func layout(window: CGRect, capsuleFrame: CGRect, paneFrame: CGRect) {
        capsule = EdgeGeometry.localRect(of: capsuleFrame, in: window)
        pane = EdgeGeometry.localRect(of: paneFrame, in: window)
    }

    /// Starts heading for a state from wherever the shape is now, so reversing partway is continuous.
    public func beginMove(expanded: Bool, curve: SpringCurve, now: Date = Date()) {
        motion.start(toward: expanded ? 1 : 0, at: now, curve: curve)
        isExpanded = expanded
        isMoving = true
    }

    public func endMove() {
        isMoving = false
    }

    /// Goes straight to a state with no motion.
    public func snap(expanded: Bool) {
        motion.snap(to: expanded ? 1 : 0)
        isExpanded = expanded
        isMoving = false
    }
}
