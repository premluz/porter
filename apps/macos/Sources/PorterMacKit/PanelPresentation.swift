import CoreGraphics
import Foundation
import Observation

/// What SwiftUI draws: where the one glass shape sits inside the window, and how far along its move it
/// is. The window is sized once per move; the shape's progress comes from a spring computed from the
/// clock (see PanelMotion), so each frame of the move is known and testable.
public enum DragPhase: Sendable { case changed, ended }

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
    public nonisolated static let coordinateSpace = "panel"
    /// The dot (or the open button, `PanelPresentation.openButtonId`) under the pointer, for its hover look.
    public var hoveredDot: String?
    public nonisolated static let openButtonId = "open"
    /// The open pane's rows by item id, and the part of the pane they are visible in, in the window's top-left
    /// coordinates. Read when the pointer moves, like `dotFrames`; not observed.
    @ObservationIgnored public var rowFrames: [String: CGRect] = [:]
    @ObservationIgnored public var listFrame = CGRect.zero
    /// The row under the pointer in the open pane, for its hover look.
    public var hoveredRow: String?
    /// Told when the person drags the capsule; the controller moves the window, since only it knows the screen.
    @ObservationIgnored public var onDrag: ((DragPhase) -> Void)?
    /// A drag ends with the pointer still over a dot, and releasing it would press that dot; for a moment after a
    /// drag, presses are ignored.
    @ObservationIgnored public var clicksIgnoredUntil = Date.distantPast
    /// Attached only by the animation probe, to see each frame of a move.
    @ObservationIgnored public var recorder: (@Sendable (CGRect) -> Void)?
    /// The shape the panel rests in when it is not open, and the one it was moving from; the window's top-left coordinates.
    public private(set) var rest = ShapeSpec(rect: .zero, corner: 0, edge: .right, kind: .capsule(.vertical))
    public private(set) var restFrom = ShapeSpec(rect: .zero, corner: 0, edge: .right, kind: .capsule(.vertical))
    /// Progress of the move from `restFrom` to `rest`: 1 when the panel is at rest.
    public private(set) var restMotion = MotionState(curve: SpringCurve(duration: Tokens.Motion.springDuration, bounce: Tokens.Motion.springBounce))
    public private(set) var isRestMoving = false

    /// Which way the capsule lies, from whichever of the two resting shapes is a capsule.
    public var capsuleOrientation: PanelOrientation {
        if case .capsule(let orientation) = rest.kind { return orientation }
        if case .capsule(let orientation) = restFrom.kind { return orientation }
        return .vertical
    }
    public private(set) var pane = ShapeSpec(rect: .zero, corner: 0, edge: .right, kind: .pane)

    public init() {}

    /// Sets the two shapes with no motion.
    public func layout(rest newRest: ShapeSpec, pane newPane: ShapeSpec) {
        rest = newRest
        restFrom = newRest
        restMotion.snap(to: 1)
        isRestMoving = false
        pane = newPane
    }

    /// The resting shape at a moment: on its way from where it was to where it rests.
    public func restShape(at now: Date) -> ShapeSpec {
        restFrom.blended(toward: rest, restMotion.progress(at: now))
    }

    /// The whole panel at a moment: its resting shape, opened towards the pane by the open and close motion.
    public func shape(at now: Date) -> ShapeSpec {
        restShape(at: now).blended(toward: pane, motion.progress(at: now))
    }

    /// Moves the resting shape from one to another, the new pane going with it.
    public func beginRestMove(from: ShapeSpec, to: ShapeSpec, pane newPane: ShapeSpec, curve: SpringCurve, now: Date = Date()) {
        restFrom = from
        rest = to
        pane = newPane
        restMotion.snap(to: 0)
        restMotion.start(toward: 1, at: now, curve: curve)
        isRestMoving = true
    }

    /// Replaces the resting shape with no motion, for when the panel is open and nothing of it shows.
    public func replaceRest(_ spec: ShapeSpec) {
        rest = spec
        restFrom = spec
        restMotion.snap(to: 1)
        isRestMoving = false
    }

    public func endRestMove() {
        restFrom = rest
        restMotion.snap(to: 1)
        isRestMoving = false
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

    /// Whether anything is animating, so the view redraws every frame only while it must.
    public var isAnimating: Bool { isMoving || isRestMoving }

    /// Goes straight to a state with no motion.
    public func snap(expanded: Bool) {
        motion.snap(to: expanded ? 1 : 0)
        isExpanded = expanded
        isMoving = false
    }
}
