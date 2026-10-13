import Foundation

/// The live mascot's animation, step by step; a port of Rios Brand's `core.ts` that must reproduce its parity scenarios.
public struct MascotState: Sendable, Equatable {
    public struct Agent: Sendable, Equatable {
        var gaze: MascotGaze
        var blink: MascotBlink
        var expression: MascotExpression
    }

    public internal(set) var time = 0.0
    let seed: UInt32
    var agents: [Agent]
    var layout: MascotLayout

    public init(spec: MascotSpec, seed: UInt32) {
        self.seed = seed
        agents = [Self.newAgent(seed: seed, index: 0, emotion: .neutral, spec: spec)]
        layout = MascotLayout(spec: spec)
    }

    static func newAgent(seed: UInt32, index: Int, emotion: MascotEmotion, spec: MascotSpec) -> Agent {
        let own = MascotRandom.agentSeed(seed, index: index)
        return Agent(gaze: MascotGaze(seed: own, motion: spec.motion), blink: MascotBlink(seed: MascotRandom.agentSeed(own, index: 1), motion: spec.motion),
                     expression: MascotExpression(emotion, spec: spec))
    }
}

/// What the mascot is asked to do: where the cursor is (body widths from the centre, y down) and one expression per agent.
public struct MascotInput: Sendable, Equatable {
    public var cursor: MascotPoint?
    public var expressions: [MascotEmotion]
    public init(cursor: MascotPoint?, expressions: [MascotEmotion]) { self.cursor = cursor; self.expressions = expressions }
}

/// What to draw for one agent.
public struct MascotAgentFrame: Sendable, Equatable, Decodable {
    public let x, scale, squash, tilt, gazeX, gazeY, openingLeft, openingRight, brow, browAngle: Double
}

public enum MascotStepError: Error, Equatable {
    case invalidTime(Double)
}

extension MascotState {
    public func stepped(_ input: MascotInput, spec: MascotSpec, dt: Double) throws(MascotStepError) -> MascotState {
        guard dt > 0, dt.isFinite else { throw .invalidTime(dt) }
        var next = self
        next.layout = layout.stepped(count: input.expressions.count, spec: spec, dt: dt)
        next.agents = next.layout.current(spec).enumerated().map { index, place in
            let emotion = index < input.expressions.count ? input.expressions[index] : input.expressions.last ?? .neutral
            let agent = index < agents.count ? agents[index] : Self.newAgent(seed: seed, index: index, emotion: emotion, spec: spec)
            let expression = agent.expression.stepped(toward: emotion, spec: spec, dt: dt)
            let look = input.cursor.map { MascotGaze.look(at: $0, from: MascotPoint(x: place.x, y: 0)) }
            let face = expression.current(spec)
            return Agent(
                gaze: agent.gaze.stepped(look: look, rest: MascotPoint(x: face.gazeX, y: face.gazeY), motion: spec.motion, dt: dt),
                blink: agent.blink.stepped(motion: spec.motion, allowed: !expression.isChanging, dt: dt), expression: expression
            )
        }
        next.time = time + dt
        return next
    }

    public var agentCount: Int { layout.count }

    public func frame(_ spec: MascotSpec) -> [MascotAgentFrame] {
        let places = layout.current(spec)
        let breath = spec.motion.breathDepth * sin(2 * Double.pi * time / spec.motion.breathPeriod)
        return zip(agents, places).map { agent, place in
            let face = agent.expression.current(spec)
            let open = agent.blink.openness(spec.motion)
            return MascotAgentFrame(
                x: place.x, scale: place.scale, squash: breath + agent.expression.changeSquash(spec), tilt: face.tilt,
                gazeX: agent.gaze.x.value, gazeY: agent.gaze.y.value, openingLeft: face.openingLeft * open,
                openingRight: face.openingRight * open, brow: face.brow, browAngle: face.browAngle
            )
        }
    }
}
