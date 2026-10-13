/// Mulberry32 on 32-bit integers, the same generator as Rios Brand's `random.ts`, so both draw identical numbers.
/// The constants are the algorithm's own.
public enum MascotRandom {
    public struct Draw: Sendable, Equatable {
        public let value: Double
        public let seed: UInt32
    }

    public static func next(_ seed: UInt32) -> Draw {
        let state = seed &+ 0x6D2B_79F5
        var t = (state ^ (state >> 15)) &* (state | 1)
        t = t ^ (t &+ ((t ^ (t >> 7)) &* (t | 61)))
        return Draw(value: Double(t ^ (t >> 14)) / 4_294_967_296, seed: state)
    }

    public static func draw(_ seed: UInt32, in range: MascotSpec.Range) -> Draw {
        let draw = next(seed)
        return Draw(value: range.min + (range.max - range.min) * draw.value, seed: draw.seed)
    }

    /// A separate stream for each agent, so adding one does not change the others' blinks.
    public static func agentSeed(_ seed: UInt32, index: Int) -> UInt32 {
        seed ^ (UInt32(index + 1) &* 0x9E37_79B1)
    }
}

public struct MascotSpring: Sendable, Equatable {
    public var value: Double
    public var velocity: Double

    public static let rest = MascotSpring(value: 0, velocity: 0)
    /// Fixed sub-steps, as in Rios Brand's `spring.ts`, so the result does not depend on how the frame time rounds.
    static let substep = 1.0 / 240

    /// A damped spring toward `target` (`response` is the period in seconds, `damping` 1 is critical), integrated with
    /// semi-implicit Euler in equal sub-steps. The arithmetic follows the TypeScript term for term.
    public func stepped(toward target: Double, response: Double, damping: Double, dt: Double) -> MascotSpring {
        let omega = 2 * Double.pi / response
        let steps = max(1, Int((dt / Self.substep - 1e-9).rounded(.up)))
        let h = dt / Double(steps)
        var value = self.value, velocity = self.velocity
        for _ in 0..<steps {
            velocity += (omega * omega * (target - value) - 2 * damping * omega * velocity) * h
            value += velocity * h
        }
        return MascotSpring(value: value, velocity: velocity)
    }
}
