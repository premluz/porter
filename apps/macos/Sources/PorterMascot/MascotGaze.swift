import Foundation

/// A point in the mascot's plane: body widths from the centre, y down.
public struct MascotPoint: Sendable, Equatable, Decodable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    public static let zero = MascotPoint(x: 0, y: 0)

    /// Pulled back onto the unit disk when outside it, as `unitDisk` in Rios Brand.
    var onUnitDisk: MascotPoint {
        let divisor = max(1, (x * x + y * y).squareRoot())
        return MascotPoint(x: x / divisor, y: y / divisor)
    }
}

/// Where the eyes look and how they move; mirrors Rios Brand's `gaze.ts`.
public struct MascotGaze: Sendable, Equatable {
    public var x = MascotSpring.rest
    public var y = MascotSpring.rest
    var target = MascotPoint.zero
    var still = 0.0
    var saccade = MascotPoint.zero
    var saccadeIn: Double
    var seed: UInt32

    /// A new target closer than this to the last one is the same target.
    static let sameTarget = 1e-3

    init(seed: UInt32, motion: MascotSpec.Motion) {
        let first = MascotRandom.draw(seed, in: motion.saccadeInterval)
        saccadeIn = first.value
        self.seed = first.seed
    }

    /// The direction of a point from an eye, on the gaze disk: far away is the edge, close by is part way.
    static func look(at point: MascotPoint, from origin: MascotPoint) -> MascotPoint {
        let dx = point.x - origin.x, dy = point.y - origin.y
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance >= 1e-6 else { return .zero }
        let reach = distance / (distance + 1)
        return MascotPoint(x: dx / distance * reach, y: dy / distance * reach)
    }

    private mutating func nextSaccade(_ motion: MascotSpec.Motion) {
        let angle = MascotRandom.next(seed)
        let size = MascotRandom.next(angle.seed)
        let wait = MascotRandom.draw(size.seed, in: motion.saccadeInterval)
        let radius = motion.saccadeSize * size.value, turn = angle.value * Double.pi * 2
        saccade = MascotPoint(x: cos(turn) * radius, y: sin(turn) * radius)
        saccadeIn = wait.value
        seed = wait.seed
    }

    func stepped(look: MascotPoint?, rest: MascotPoint, motion: MascotSpec.Motion, dt: Double) -> MascotGaze {
        var next = self
        next.still += dt
        next.saccadeIn -= dt
        if let look, Self.distance(look, target) > Self.sameTarget {
            next.target = look
            next.still = 0
            next.saccade = .zero
        }
        if next.saccadeIn <= 0 { next.nextSaccade(motion) }
        let resting = look == nil || next.still > motion.returnDelay
        let aim = (resting ? rest : MascotPoint(x: next.target.x + next.saccade.x, y: next.target.y + next.saccade.y)).onUnitDisk
        next.x = next.x.stepped(toward: aim.x, response: motion.gazeResponse, damping: motion.gazeDamping, dt: dt)
        next.y = next.y.stepped(toward: aim.y, response: motion.gazeResponse, damping: motion.gazeDamping, dt: dt)
        return next
    }

    private static func distance(_ a: MascotPoint, _ b: MascotPoint) -> Double {
        let dx = a.x - b.x, dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
