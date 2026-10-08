import ConversationCore
import Foundation

public enum PacketReviewError: Error, Equatable, Sendable {
    case overLimit(characters: Int, limit: Int)
    case nothingToCopy
}

/// The review step: what would be copied, from which sources, and where it is meant to go.
/// Nothing leaves this value until the user asks for it.
public struct PacketReview: Sendable, Equatable {
    public static let maximumCharacters = 16_000

    public let packet: ContextPacket
    public private(set) var included: Set<Int>

    /// Only current sources start included. Stale or unverifiable ones need an explicit choice.
    public init(packet: ContextPacket) {
        self.packet = packet
        included = Set(packet.sources.indices.filter { packet.sources[$0].freshness == .current })
    }

    public mutating func toggle(_ index: Int) {
        guard packet.sources.indices.contains(index) else { return }
        if included.contains(index) { included.remove(index) } else { included.insert(index) }
    }

    public var warnings: [String] {
        packet.sources.indices.compactMap { index in
            let source = packet.sources[index]
            switch (source.freshness, included.contains(index)) {
            case (.stale, true): return "“\(source.citation)” is out of date but included."
            case (.unknown, true): return "“\(source.citation)” could not be checked for freshness."
            case (.stale, false): return "“\(source.citation)” is out of date, so it is left out."
            default: return nil
            }
        }
    }

    public func rendered() throws(PacketReviewError) -> String {
        let text = Self.text(packet, included: included)
        guard packet.instruction != nil || !included.isEmpty else { throw .nothingToCopy }
        guard text.count <= Self.maximumCharacters else {
            throw .overLimit(characters: text.count, limit: Self.maximumCharacters)
        }
        return text
    }

    public var characterCount: Int { Self.text(packet, included: included).count }

    public var isOverLimit: Bool { characterCount > Self.maximumCharacters }

    /// Every open conversation that matches the requested destination. More than one means the same
    /// chat is open under several profiles, so the user chooses; Porter never picks between them.
    public func destinationCandidates(in items: [PanelItem]) -> [PanelItem] {
        guard let wanted = packet.requestedDestination else { return [] }
        return items.filter {
            $0.key.provider == wanted.provider && $0.key.providerConversationId == wanted.providerConversationId
        }
    }

    private static func text(_ packet: ContextPacket, included: Set<Int>) -> String {
        var lines = [packet.title]
        if let instruction = packet.instruction { lines += ["", "Instruction:", instruction] }
        if let task = packet.task { lines += ["", "Task: \(task.label ?? task.id)"] }
        let chosen = packet.sources.indices.filter(included.contains)
        if !chosen.isEmpty { lines += ["", "Context:"] }
        for (position, index) in chosen.enumerated() {
            let source = packet.sources[index]
            lines += ["", "[\(position + 1)] \(source.citation) (\(describe(source)))", source.excerpt]
        }
        return lines.joined(separator: "\n")
    }

    private static func describe(_ source: PacketSource) -> String {
        var parts = ["Memento \(source.reference.type == .mementoSource ? "source" : "entry") \(source.reference.id)"]
        if let revision = source.reference.revision { parts.append("revision \(revision)") }
        parts.append(source.freshness.rawValue)
        return parts.joined(separator: ", ")
    }
}
