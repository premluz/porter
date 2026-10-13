import Foundation

/// The live mascot's character, as exported by Rios Brand (`spec/mascot-spec.v1.json`). Rios Brand checks every field
/// strictly; here the version is checked, so a spec Porter does not understand is refused rather than misread.
public struct MascotSpec: Decodable, Sendable, Equatable {
    public static let supportedVersion = 1

    public struct Palette: Decodable, Sendable, Equatable { public let body, limb, ink, white: String }
    public struct Body: Decodable, Sendable, Equatable { public let rx, ry, rz: Double }
    public struct Eyes: Decodable, Sendable, Equatable { public let style: String; public let x, y, rx, ry, gazeTravel: Double }
    public struct Expression: Decodable, Sendable, Equatable {
        public let openingLeft, openingRight, brow, browAngle, gazeX, gazeY, tilt: Double
    }
    public struct Range: Decodable, Sendable, Equatable { public let min, max: Double }
    public struct Motion: Decodable, Sendable, Equatable {
        public let gazeResponse, gazeDamping: Double
        public let saccadeInterval: Range
        public let saccadeSize, returnDelay: Double
        public let blinkInterval: Range
        public let blinkDuration, doubleBlinkChance, expressionBlend, changeSquash, breathPeriod, breathDepth: Double
    }
    public struct Liquid: Decodable, Sendable, Equatable {
        public let fusion, splitDistance, neckTime: Double
        public let maximumAgents: Int
        public let agentScale: [Double]
    }
    public struct Light: Decodable, Sendable, Equatable {
        public let x, y, z, shadow, edge, edgeFocus: Double
        public let highlight: String
        public let highlightStrength, highlightFocus: Double
    }

    public let version: Int
    public let palettes: [String: Palette]
    public let body: Body
    public let eyes: Eyes
    public let expressions: [MascotEmotion: Expression]
    public let motion: Motion
    public let liquid: Liquid
    public let light: Light

    public func expression(_ emotion: MascotEmotion) -> Expression {
        guard let found = expressions[emotion] else { preconditionFailure("The mascot spec has no \(emotion) expression") }
        return found
    }
}

public enum MascotEmotion: String, Codable, Sendable, CaseIterable, CodingKeyRepresentable {
    case neutral, happy, curious, surprised, sleepy, concerned, angry
}

public enum MascotSpecError: Error, Equatable, CustomStringConvertible {
    case unsupportedVersion(Int)
    case incomplete(String)
    case missingResource

    public var description: String {
        switch self {
        case .unsupportedVersion(let version): "The mascot spec is version \(version); Porter reads version \(MascotSpec.supportedVersion)"
        case .incomplete(let what): "The mascot spec is incomplete: \(what)"
        case .missingResource: "The bundled mascot spec is missing"
        }
    }
}

extension MascotSpec {
    public static func decode(_ data: Data) throws -> MascotSpec {
        let spec = try JSONDecoder().decode(MascotSpec.self, from: data)
        guard spec.version == supportedVersion else { throw MascotSpecError.unsupportedVersion(spec.version) }
        let missing = MascotEmotion.allCases.filter { spec.expressions[$0] == nil }
        guard missing.isEmpty else { throw MascotSpecError.incomplete("expressions \(missing.map(\.rawValue))") }
        guard spec.liquid.agentScale.count == spec.liquid.maximumAgents, spec.liquid.maximumAgents >= 1 else {
            throw MascotSpecError.incomplete("one agent size per possible agent count")
        }
        return spec
    }

    /// The spec bundled with Porter, copied from Rios Brand by `tools/sync_mascot_spec.sh`.
    public static func bundled() throws -> MascotSpec {
        try decode(Data(contentsOf: bundledURL()))
    }

    static func bundledURL() throws -> URL {
        guard let url = Bundle.module.url(forResource: "mascot-spec.v1", withExtension: "json") else { throw MascotSpecError.missingResource }
        return url
    }
}
