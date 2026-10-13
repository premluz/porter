import Foundation

/// Expression blending; mirrors Rios Brand's `expression.ts`.
public struct MascotExpression: Sendable, Equatable {
    var from: MascotSpec.Expression
    var to: MascotEmotion
    var progress: Double

    init(_ emotion: MascotEmotion, spec: MascotSpec) {
        from = spec.expression(emotion)
        to = emotion
        progress = 1
    }

    static func smooth(_ value: Double) -> Double {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }

    private static func mix(_ a: MascotSpec.Expression, _ b: MascotSpec.Expression, _ amount: Double) -> MascotSpec.Expression {
        func m(_ x: Double, _ y: Double) -> Double { x + (y - x) * amount }
        return MascotSpec.Expression(
            openingLeft: m(a.openingLeft, b.openingLeft), openingRight: m(a.openingRight, b.openingRight), brow: m(a.brow, b.brow),
            browAngle: m(a.browAngle, b.browAngle), gazeX: m(a.gazeX, b.gazeX), gazeY: m(a.gazeY, b.gazeY), tilt: m(a.tilt, b.tilt)
        )
    }

    func current(_ spec: MascotSpec) -> MascotSpec.Expression {
        Self.mix(from, spec.expression(to), Self.smooth(progress))
    }

    /// A new target starts from wherever the face is now, so a change in the middle of another is continuous.
    func stepped(toward target: MascotEmotion, spec: MascotSpec, dt: Double) -> MascotExpression {
        var next = self
        if target != to {
            next.from = current(spec)
            next.to = target
            next.progress = 0
        }
        next.progress = min(1, next.progress + dt / spec.motion.expressionBlend)
        return next
    }

    var isChanging: Bool { progress < 1 }

    func changeSquash(_ spec: MascotSpec) -> Double {
        spec.motion.changeSquash * sin(Double.pi * progress)
    }
}
