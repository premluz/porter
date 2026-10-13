/// Where an agent sits, in body widths from the character's centre, and its size; mirrors Rios Brand's `agents.ts`.
public struct MascotPlacement: Sendable, Equatable {
    public var x: Double
    public var scale: Double
}

public struct MascotLayout: Sendable, Equatable {
    var from: [MascotPlacement]
    var count: Int
    var progress: Double

    init(spec: MascotSpec) {
        from = Self.placements(1, spec: spec)
        count = 1
        progress = 1
    }

    static func clampCount(_ count: Int, spec: MascotSpec) -> Int {
        min(max(count, 1), spec.liquid.maximumAgents)
    }

    /// Agents in a row, centred, spaced by the split distance at their size.
    static func placements(_ count: Int, spec: MascotSpec) -> [MascotPlacement] {
        let scale = spec.liquid.agentScale[count - 1]
        let spacing = spec.liquid.splitDistance * scale
        return (0..<count).map { MascotPlacement(x: (Double($0) - Double(count - 1) / 2) * spacing, scale: scale) }
    }

    /// A new agent grows out of the last existing one; a leaving one moves into the last remaining one.
    func current(_ spec: MascotSpec) -> [MascotPlacement] {
        let target = Self.placements(count, spec: spec)
        let amount = MascotExpression.smooth(progress)
        return (0..<max(from.count, target.count)).map { index in
            let start = index < from.count ? from[index] : from[from.count - 1]
            let end = index < target.count ? target[index] : target[target.count - 1]
            return MascotPlacement(x: start.x + (end.x - start.x) * amount, scale: start.scale + (end.scale - start.scale) * amount)
        }
    }

    func stepped(count wanted: Int, spec: MascotSpec, dt: Double) -> MascotLayout {
        let wanted = Self.clampCount(wanted, spec: spec)
        var next = self
        if wanted != count {
            next.from = current(spec)
            next.count = wanted
            next.progress = 0
        }
        next.progress = min(1, next.progress + dt / spec.liquid.neckTime)
        if next.progress >= 1 { next.from = Self.placements(wanted, spec: spec) }
        return next
    }
}
