import Foundation
import Testing
@testable import PorterMascot

/// The scenarios Rios Brand recorded (`spec/mascot-parity.v1.json`), replayed here: the Swift port must produce the same
/// frames. Copied by `tools/sync_mascot_spec.sh`; never edited in Porter.
private struct ParityFile: Decodable {
    struct Segment: Decodable { let frames: Int; let dt: Double; let cursor: MascotPoint?; let expressions: [MascotEmotion] }
    struct Sample: Decodable { let step: Int; let time: Double; let agents: [MascotAgentFrame] }
    struct Scenario: Decodable { let name: String; let seed: UInt32; let sampleEvery: Int; let segments: [Segment]; let samples: [Sample] }
    let version: Int
    let specVersion: Int
    let scenarios: [Scenario]

    static func load() throws -> ParityFile {
        let url = try #require(Bundle.module.url(forResource: "mascot-parity.v1", withExtension: "json"))
        return try JSONDecoder().decode(ParityFile.self, from: Data(contentsOf: url))
    }
}

/// Absolute for values near zero, relative for large ones; both ports use IEEE doubles and the same order of operations,
/// so only the last bits of library functions such as `sin` can differ.
private let tolerance = 1e-9

private func mismatches(_ expected: MascotAgentFrame, _ actual: MascotAgentFrame) -> [String] {
    let pairs: [(String, Double, Double)] = [
        ("x", expected.x, actual.x), ("scale", expected.scale, actual.scale), ("squash", expected.squash, actual.squash),
        ("tilt", expected.tilt, actual.tilt), ("gazeX", expected.gazeX, actual.gazeX), ("gazeY", expected.gazeY, actual.gazeY),
        ("openingLeft", expected.openingLeft, actual.openingLeft), ("openingRight", expected.openingRight, actual.openingRight),
        ("brow", expected.brow, actual.brow), ("browAngle", expected.browAngle, actual.browAngle),
    ]
    return pairs.filter { abs($0.1 - $0.2) > tolerance * max(1, abs($0.1)) }.map { "\($0.0) expected \($0.1), got \($0.2)" }
}

@Suite("The Swift mascot core reproduces Rios Brand's recorded scenarios")
struct MascotParityTests {
    @Test("the bundled spec and the parity file are the same version")
    func versions() throws {
        let parity = try ParityFile.load()
        #expect(parity.version == 1 && parity.specVersion == MascotSpec.supportedVersion && !parity.scenarios.isEmpty)
    }

    @Test("every sampled frame of every scenario matches")
    func scenarios() throws {
        let spec = try MascotSpec.bundled()
        for scenario in try ParityFile.load().scenarios {
            var state = MascotState(spec: spec, seed: scenario.seed)
            var count = 0
            var samples = scenario.samples.makeIterator()
            for segment in scenario.segments {
                for _ in 0..<segment.frames {
                    state = try state.stepped(MascotInput(cursor: segment.cursor, expressions: segment.expressions), spec: spec, dt: segment.dt)
                    count += 1
                    guard count % scenario.sampleEvery == 0 else { continue }
                    let next = samples.next()
                    let expected = try #require(next, "\(scenario.name): more samples than recorded")
                    let actual = state.frame(spec)
                    #expect(expected.step == count && abs(expected.time - state.time) <= tolerance)
                    try #require(expected.agents.count == actual.count, "\(scenario.name) step \(count): \(actual.count) agents, expected \(expected.agents.count)")
                    for (index, pair) in zip(expected.agents, actual).enumerated() {
                        let problems = mismatches(pair.0, pair.1)
                        try #require(problems.isEmpty, "\(scenario.name) step \(count) agent \(index): \(problems.joined(separator: "; "))")
                    }
                }
            }
            let leftover = samples.next()
            #expect(leftover == nil, "\(scenario.name): fewer samples than recorded")
        }
    }
}
