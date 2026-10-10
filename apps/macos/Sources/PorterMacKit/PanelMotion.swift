import CoreGraphics
import Foundation

/// The panel's spring, as plain math. Time in, progress out, so the motion can be tested without a
/// screen and every frame of it is known. It is the standard damped spring that SwiftUI's own
/// `spring(duration:bounce:)` describes: the damping ratio is `1 - bounce`.
public struct SpringCurve: Sendable, Equatable {
    /// How small the remaining wobble must be to call the move finished.
    private static let settleThreshold = 0.001

    public let duration: TimeInterval
    public let bounce: Double

    public init(duration: TimeInterval, bounce: Double) {
        self.duration = max(duration, 0.01)
        self.bounce = min(max(bounce, 0), 0.9)
    }

    private var damping: Double { 1 - bounce }
    private var frequency: Double { 2 * .pi / duration }

    /// 0 at the start, 1 once settled, with overshoot past 1 on the way when bounce is above zero.
    public func value(at elapsed: TimeInterval) -> Double {
        guard elapsed > 0 else { return 0 }
        guard elapsed < settlingTime else { return 1 }
        let decay = exp(-damping * frequency * elapsed)
        if bounce == 0 { return 1 - decay * (1 + frequency * elapsed) }
        let damped = frequency * (1 - damping * damping).squareRoot()
        return 1 - decay * (cos(damped * elapsed) + damping * frequency / damped * sin(damped * elapsed))
    }

    /// When the envelope of the wobble has shrunk below a thousandth of the distance travelled.
    public var settlingTime: TimeInterval {
        -log(Self.settleThreshold) / (damping * frequency)
    }

    /// The largest overshoot beyond the target, as a fraction of the distance travelled.
    public var overshoot: Double {
        bounce == 0 ? 0 : exp(-Double.pi * damping / (1 - damping * damping).squareRoot())
    }
}

/// One move of the panel between its two shapes. A new move starts from wherever the last one had
/// reached, so reversing partway looks continuous instead of jumping to an end.
public struct MotionState: Sendable, Equatable {
    public private(set) var from = 0.0
    public private(set) var target = 0.0
    public private(set) var startedAt = Date.distantPast
    public private(set) var curve: SpringCurve
    /// Where the content's fade stood when this move began, so a reversal continues it.
    public private(set) var contentFrom = 0.0

    public init(curve: SpringCurve) {
        self.curve = curve
    }

    public func progress(at now: Date) -> Double {
        from + (target - from) * curve.value(at: now.timeIntervalSince(startedAt))
    }

    /// How far the content (rows, search, footer) has faded in, 0...1. It runs on the clock, not on the
    /// spring: the shape reaches its size early and then bounces, but the content should arrive last.
    /// Closing is quicker, so text is gone before the shape is too narrow to hold it.
    public func contentProgress(at now: Date) -> Double {
        let span = target > 0.5 ? curve.settlingTime : curve.settlingTime * Tokens.Motion.contentCloseFraction
        let fraction = min(max(now.timeIntervalSince(startedAt) / span, 0), 1)
        return contentFrom + (target - contentFrom) * fraction
    }

    public func isSettled(at now: Date) -> Bool {
        now.timeIntervalSince(startedAt) >= curve.settlingTime
    }

    public mutating func start(toward newTarget: Double, at now: Date, curve newCurve: SpringCurve) {
        contentFrom = contentProgress(at: now)
        from = progress(at: now)
        target = newTarget
        startedAt = now
        curve = newCurve
    }

    /// Jumps to an end with no motion, used when the screen is not being drawn or in tests.
    public mutating func snap(to newTarget: Double) {
        from = newTarget
        contentFrom = newTarget
        target = newTarget
        startedAt = .distantPast
    }
}

/// How each part of the panel follows the progress of the move. All are 0...1 and pure.
public enum PanelPhases {
    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    private static func smooth(_ value: Double) -> Double {
        let t = clamp(value)
        return t * t * (3 - 2 * t)
    }

    /// How much of the resting content is the tab's and how much the capsule's, while the panel moves between them.
    public static func restBlend(fromTab: Bool, toTab: Bool, progress: Double) -> (tab: Double, capsule: Double) {
        let amount = smooth(progress)
        let tab = fromTab == toTab ? (toTab ? 1 : 0) : (toTab ? amount : 1 - amount)
        return (tab, 1 - tab)
    }

    /// The capsule's dots fade out early in the move, before the shape is wide enough to stretch them.
    public static func capsuleOpacity(progress: Double) -> Double {
        1 - smooth(progress / Tokens.Motion.capsuleFadeEnd)
    }

    /// The pane's content waits until the shape has grown, so text is never shown on a narrow shape.
    /// `progress` here and in `rowOpacity` is the content's own timeline (`MotionState.contentProgress`).
    public static func paneOpacity(progress: Double) -> Double {
        smooth((progress - Tokens.Motion.contentRevealStart) / Tokens.Motion.contentRevealSpan)
    }

    /// Rows rise in one after another; `order` is capped so a long list does not drag the reveal out.
    public static func rowOpacity(progress: Double, order: Int) -> Double {
        let steps = Double(min(max(order, 0), Tokens.Motion.staggerLimit))
        return smooth((progress - Tokens.Motion.contentRevealStart - steps * Tokens.Motion.staggerStep) / Tokens.Motion.contentRevealSpan)
    }

    public static func rowOffset(progress: Double, order: Int) -> CGFloat {
        CGFloat(1 - rowOpacity(progress: progress, order: order)) * Tokens.Motion.rowRise
    }
}
