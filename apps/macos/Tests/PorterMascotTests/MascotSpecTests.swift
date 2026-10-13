import Foundation
import Testing
@testable import PorterMascot

@Suite("The bundled mascot spec")
struct MascotSpecTests {
    @Test("it decodes, with every expression and one size per agent count")
    func bundled() throws {
        let spec = try MascotSpec.bundled()
        #expect(spec.version == 1 && spec.eyes.style == "capsule")
        #expect(Set(spec.expressions.keys) == Set(MascotEmotion.allCases))
        #expect(spec.liquid.agentScale.count == spec.liquid.maximumAgents)
    }

    @Test("another version, or a spec missing an expression, is refused")
    func refusals() throws {
        let raw = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: MascotSpec.bundledURL())) as? [String: Any])
        var newer = raw
        newer["version"] = 2
        #expect(throws: MascotSpecError.unsupportedVersion(2)) { try MascotSpec.decode(JSONSerialization.data(withJSONObject: newer)) }
        var missing = raw
        var expressions = try #require(raw["expressions"] as? [String: Any])
        expressions["sleepy"] = nil
        missing["expressions"] = expressions
        #expect(throws: MascotSpecError.incomplete("expressions [\"sleepy\"]")) { try MascotSpec.decode(JSONSerialization.data(withJSONObject: missing)) }
    }

    @Test("a step needs a positive, finite time")
    func badTime() throws {
        let spec = try MascotSpec.bundled()
        for dt in [0, -0.1, Double.nan, Double.infinity] {
            #expect(throws: MascotStepError.self) { try MascotState(spec: spec, seed: 1).stepped(MascotInput(cursor: nil, expressions: [.neutral]), spec: spec, dt: dt) }
        }
    }
}
