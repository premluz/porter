import Foundation

public enum PacketCreator: String, Codable, Sendable { case atlas, manager, memento }

public enum SourceFreshness: String, Codable, Sendable { case current, stale, unknown }

/// A short cited excerpt from a Memento source. The record itself stays in Memento.
public struct PacketSource: Codable, Sendable, Equatable {
    public let reference: SuiteReference
    public let citation: String
    public let excerpt: String
    public let freshness: SourceFreshness
}

public struct PacketDestination: Codable, Sendable, Equatable {
    public let provider: String
    public let providerConversationId: String
}

/// Mirrors context-packet.schema.json. Porter only displays it and copies it on request; it is
/// never stored and never typed into a chat.
public struct ContextPacket: Codable, Sendable, Equatable, Identifiable {
    public let packetVersion: String
    public let id: UUID
    public let createdAt: Date
    public let createdBy: PacketCreator
    public let title: String
    public let instruction: String?
    public let capture: SuiteReference?
    public let task: SuiteReference?
    public let sources: [PacketSource]
    public let requestedDestination: PacketDestination?
}

public enum PacketRejection: Error, Equatable, Sendable {
    case tooLarge(bytes: Int)
    case unsupportedVersion(String)
    case malformed(String)
    case invalid(String)
}

public enum ContextPacketDecoder {
    public static let maximumBytes = 256 * 1024
    public static let maximumSources = 20
    public static let maximumTitle = 120
    public static let maximumInstruction = 2_000
    public static let maximumCitation = 200
    public static let maximumExcerpt = 4_000
    private static let supportedMajor = "1."

    /// Size first, then structure, then the limits the schema states, so a bad file is refused whole.
    public static func decode(_ data: Data) throws(PacketRejection) -> ContextPacket {
        guard data.count <= maximumBytes else { throw .tooLarge(bytes: data.count) }
        try rejectUnknownFields(in: data)
        let packet: ContextPacket
        do {
            packet = try ContractCoding.decoder().decode(ContextPacket.self, from: data)
        } catch {
            throw .malformed(String(describing: error))
        }
        guard packet.packetVersion.hasPrefix(supportedMajor) else { throw .unsupportedVersion(packet.packetVersion) }
        try check(packet)
        return packet
    }

    private static let packetKeys: Set<String> = [
        "packetVersion", "id", "createdAt", "createdBy", "title", "instruction", "capture", "task", "sources", "requestedDestination",
    ]
    private static let sourceKeys: Set<String> = ["reference", "citation", "excerpt", "freshness"]
    private static let destinationKeys: Set<String> = ["provider", "providerConversationId"]
    private static let referenceKeys: Set<String> = ["contract", "type", "id", "workspaceId", "revision", "label"]

    /// Swift would silently drop unknown fields. A packet with a field this contract does not name
    /// (a cookie, a message history) is refused instead, as the schema requires.
    private static func rejectUnknownFields(in data: Data) throws(PacketRejection) {
        guard let top = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw .malformed("the packet is not a JSON object")
        }
        try require(top.keys, within: packetKeys, in: "packet")
        for key in ["capture", "task"] {
            if let reference = top[key] as? [String: Any] { try require(reference.keys, within: referenceKeys, in: key) }
        }
        if let destination = top["requestedDestination"] as? [String: Any] {
            try require(destination.keys, within: destinationKeys, in: "requestedDestination")
        }
        for source in (top["sources"] as? [[String: Any]]) ?? [] {
            try require(source.keys, within: sourceKeys, in: "source")
            if let reference = source["reference"] as? [String: Any] {
                try require(reference.keys, within: referenceKeys, in: "source reference")
            }
        }
    }

    private static func require(_ found: Dictionary<String, Any>.Keys, within allowed: Set<String>, in place: String) throws(PacketRejection) {
        let extra = Set(found).subtracting(allowed)
        guard extra.isEmpty else { throw .invalid("unexpected field in \(place): \(extra.sorted().joined(separator: ", "))") }
    }

    private static func check(_ packet: ContextPacket) throws(PacketRejection) {
        guard (1...maximumTitle).contains(packet.title.count) else { throw .invalid("title length") }
        if let instruction = packet.instruction, !(1...maximumInstruction).contains(instruction.count) {
            throw .invalid("instruction length")
        }
        guard packet.sources.count <= maximumSources else { throw .invalid("more than \(maximumSources) sources") }
        for source in packet.sources {
            guard source.reference.type == .mementoSource || source.reference.type == .mementoEntry else {
                throw .invalid("a source must be a Memento source or entry, not \(source.reference.type.rawValue)")
            }
            guard (1...maximumCitation).contains(source.citation.count) else { throw .invalid("citation length") }
            guard (1...maximumExcerpt).contains(source.excerpt.count) else { throw .invalid("excerpt length") }
        }
    }
}
