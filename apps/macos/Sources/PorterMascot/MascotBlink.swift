import Foundation

/// Blinking; mirrors Rios Brand's `blink.ts`.
public struct MascotBlink: Sendable, Equatable {
    /// Seconds until the next blink; while blinking, how far into it (negative when the eyes are open).
    var nextIn: Double
    var closing = -1.0
    var double = false
    var seed: UInt32

    /// A second blink follows a double blink's first after this many blink lengths.
    static let doubleGap = 1.5

    init(seed: UInt32, motion: MascotSpec.Motion) {
        let wait = MascotRandom.draw(seed, in: motion.blinkInterval)
        nextIn = wait.value
        self.seed = wait.seed
    }

    private func finished(_ motion: MascotSpec.Motion) -> MascotBlink {
        var next = self
        next.closing = -1
        if double {
            next.double = false
            next.nextIn = motion.blinkDuration * Self.doubleGap
            return next
        }
        let chance = MascotRandom.next(seed)
        let wait = MascotRandom.draw(chance.seed, in: motion.blinkInterval)
        next.nextIn = wait.value
        next.double = chance.value < motion.doubleBlinkChance
        next.seed = wait.seed
        return next
    }

    /// A blink that falls due while `allowed` is false (an expression is changing) waits until it is allowed.
    func stepped(motion: MascotSpec.Motion, allowed: Bool, dt: Double) -> MascotBlink {
        var next = self
        if closing >= 0 {
            next.closing = closing + dt
            return next.closing >= motion.blinkDuration ? finished(motion) : next
        }
        next.nextIn = nextIn - dt
        if next.nextIn > 0 { return next }
        next.nextIn = 0
        if allowed { next.closing = 0 }
        return next
    }

    func openness(_ motion: MascotSpec.Motion) -> Double {
        closing < 0 ? 1 : 1 - sin(Double.pi * min(closing / motion.blinkDuration, 1))
    }
}
