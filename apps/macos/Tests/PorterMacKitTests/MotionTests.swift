import CoreGraphics
import Foundation
import Testing
@testable import PorterMacKit

@Suite("The panel's spring")
struct SpringTests {
    private let bouncy = SpringCurve(duration: 0.42, bounce: 0.3)
    private let flat = SpringCurve(duration: 0.12, bounce: 0)

    private func samples(_ curve: SpringCurve, steps: Int = 400) -> [Double] {
        (0...steps).map { curve.value(at: curve.settlingTime * Double($0) / Double(steps)) }
    }

    @Test("it starts at zero, ends at exactly one, and never reports a value before it begins")
    func endpoints() {
        for curve in [bouncy, flat] {
            #expect(curve.value(at: -1) == 0 && curve.value(at: 0) == 0)
            #expect(curve.value(at: curve.settlingTime) == 1 && curve.value(at: curve.settlingTime + 5) == 1)
        }
    }

    @Test("a bouncy spring overshoots the target by about its stated amount, once, and then settles")
    func overshoot() {
        let values = samples(bouncy)
        let peak = values.max() ?? 0
        #expect(abs((peak - 1) - bouncy.overshoot) < 0.005, "peak \(peak) vs predicted \(bouncy.overshoot)")
        #expect(bouncy.overshoot > 0.03 && bouncy.overshoot < 0.07)
        // After the peak it only moves back toward the target; that is the single settle the design asks for.
        let peakIndex = values.firstIndex(of: peak) ?? 0
        let afterPeak = values[peakIndex...]
        let crossings = zip(afterPeak, afterPeak.dropFirst()).filter { ($0 - 1) * ($1 - 1) < 0 }.count
        #expect(crossings <= 2, "after its peak it should dip below the target at most once and settle")
    }

    @Test("with no bounce it rises smoothly to the target and never passes it")
    func noBounce() {
        let values = samples(flat)
        #expect(values.max().map { $0 <= 1.0000001 } == true)
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 + 1e-9 })
        #expect(flat.overshoot == 0)
    }

    @Test("a stiffer or longer duration settles accordingly, and out-of-range bounce is clamped")
    func parameters() {
        #expect(SpringCurve(duration: 0.2, bounce: 0.3).settlingTime < SpringCurve(duration: 0.6, bounce: 0.3).settlingTime)
        #expect(SpringCurve(duration: 0.4, bounce: -2).bounce == 0)
        #expect(SpringCurve(duration: 0.4, bounce: 5).bounce == 0.9)
        #expect(SpringCurve(duration: 0, bounce: 0.2).duration > 0)
        #expect(bouncy.settlingTime > 0.3 && bouncy.settlingTime < 1.2)
    }

    @Test("the opening move reaches most of its distance well inside a quarter second")
    func feelsQuick() {
        #expect(bouncy.value(at: 0.15) > 0.6)
    }
}

@Suite("A move and reversing it")
struct MoveTests {
    private let curve = SpringCurve(duration: 0.4, bounce: 0.25)
    private let t0 = Date(timeIntervalSince1970: 1_000)

    @Test("progress runs from where the move began to its target and then stays")
    func runs() {
        var state = MotionState(curve: curve)
        state.snap(to: 0)
        state.start(toward: 1, at: t0, curve: curve)
        #expect(state.progress(at: t0) == 0)
        #expect(state.progress(at: t0.addingTimeInterval(0.1)) > 0.1)
        #expect(state.progress(at: t0.addingTimeInterval(5)) == 1)
        #expect(!state.isSettled(at: t0.addingTimeInterval(0.1)))
        #expect(state.isSettled(at: t0.addingTimeInterval(5)))
    }

    @Test("reversing halfway starts from the shape's current size, not from an end, so there is no jump")
    func reversalIsContinuous() {
        var state = MotionState(curve: curve)
        state.snap(to: 0)
        state.start(toward: 1, at: t0, curve: curve)
        let moment = t0.addingTimeInterval(0.12)
        let before = state.progress(at: moment)
        state.start(toward: 0, at: moment, curve: curve)
        #expect(abs(state.progress(at: moment) - before) < 1e-12)
        #expect(state.progress(at: moment.addingTimeInterval(5)) == 0)
    }

    @Test("snapping goes straight to an end with no motion")
    func snapping() {
        var state = MotionState(curve: curve)
        state.snap(to: 1)
        #expect(state.progress(at: t0) == 1 && state.isSettled(at: t0))
        state.snap(to: 0)
        #expect(state.progress(at: t0) == 0)
    }
}

@Suite("What follows the move")
struct PhaseTests {
    @Test("the resting content is the tab's or the capsule's, or a blend of the two while the panel moves between them")
    func restBlend() {
        #expect(PanelPhases.restBlend(fromTab: true, toTab: true, progress: 0.5) == (tab: 1, capsule: 0))
        #expect(PanelPhases.restBlend(fromTab: false, toTab: false, progress: 0.5) == (tab: 0, capsule: 1))
        let start = PanelPhases.restBlend(fromTab: true, toTab: false, progress: 0)
        let end = PanelPhases.restBlend(fromTab: true, toTab: false, progress: 1)
        #expect(start.tab == 1 && end.tab == 0 && end.capsule == 1)
        let reverse = PanelPhases.restBlend(fromTab: false, toTab: true, progress: 1)
        #expect(reverse.tab == 1 && reverse.capsule == 0)
        let halfway = PanelPhases.restBlend(fromTab: false, toTab: true, progress: 0.5)
        #expect(halfway.tab > 0 && halfway.tab < 1 && abs(halfway.tab + halfway.capsule - 1) < 1e-9)
    }

    @Test("dots fade out early and content fades in late, so text is never drawn on a narrow shape")
    func contentTiming() {
        #expect(PanelPhases.capsuleOpacity(progress: 0) == 1 && PanelPhases.capsuleOpacity(progress: 1) == 0)
        #expect(PanelPhases.paneOpacity(progress: 0) == 0 && PanelPhases.paneOpacity(progress: 1) == 1)
        #expect(PanelPhases.paneOpacity(progress: Tokens.Motion.contentRevealStart) == 0)
        // Opening: by the time the first dots are gone, the pane's text has not appeared yet.
        #expect(PanelPhases.capsuleOpacity(progress: Tokens.Motion.capsuleFadeEnd) == 0)
        #expect(PanelPhases.paneOpacity(progress: 0.15) == 0)
        var previous = -1.0
        for step in 0...20 {
            let value = PanelPhases.paneOpacity(progress: Double(step) / 20)
            #expect(value >= previous)
            previous = value
        }
    }

    @Test("rows appear one after another, later rows later, and the delay is capped for long lists")
    func stagger() {
        let progress = 0.5
        let first = PanelPhases.rowOpacity(progress: progress, order: 0)
        let third = PanelPhases.rowOpacity(progress: progress, order: 3)
        #expect(first > third)
        #expect(PanelPhases.rowOpacity(progress: progress, order: 500) == PanelPhases.rowOpacity(progress: progress, order: Tokens.Motion.staggerLimit))
        #expect(PanelPhases.rowOpacity(progress: 1, order: 500) == 1)
        #expect(PanelPhases.rowOffset(progress: 1, order: 0) == 0)
        #expect(PanelPhases.rowOffset(progress: 0, order: 0) == Tokens.Motion.rowRise)
        #expect(PanelPhases.rowOpacity(progress: progress, order: -4) == PanelPhases.rowOpacity(progress: progress, order: 0))
    }

    @Test("content arrives last: the final row is not fully visible until near the end of the move, and closing is quicker")
    func contentTimeline() {
        let curve = SpringCurve(duration: Tokens.Motion.springDuration, bounce: Tokens.Motion.springBounce)
        let start = Date(timeIntervalSinceReferenceDate: 1000)
        var motion = MotionState(curve: curve)
        motion.start(toward: 1, at: start, curve: curve)
        let settling = curve.settlingTime
        // The shape has already reached its size well before the content is done.
        #expect(motion.progress(at: start.addingTimeInterval(settling * 0.4)) > 0.95)
        #expect(motion.contentProgress(at: start.addingTimeInterval(settling * 0.4)) < 0.5)
        let last = Tokens.Motion.staggerLimit
        #expect(PanelPhases.rowOpacity(progress: 0.9, order: last) < 1)
        #expect(PanelPhases.rowOpacity(progress: 1, order: last) == 1)
        #expect(abs(motion.contentProgress(at: start.addingTimeInterval(settling)) - 1) < 1e-9)

        // Closing from fully open: the content is gone in the first part of the move.
        motion.start(toward: 0, at: start.addingTimeInterval(settling), curve: curve)
        let closeSpan = settling * Tokens.Motion.contentCloseFraction
        #expect(abs(motion.contentProgress(at: start.addingTimeInterval(settling + closeSpan))) < 1e-9)
        // Reversing halfway through the opening continues the content from where it was.
        var reversed = MotionState(curve: curve)
        reversed.start(toward: 1, at: start, curve: curve)
        let halfway = start.addingTimeInterval(settling * 0.5)
        let before = reversed.contentProgress(at: halfway)
        reversed.start(toward: 0, at: halfway, curve: curve)
        #expect(reversed.contentProgress(at: halfway) == before)
    }
}
