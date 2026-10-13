import Foundation

enum SpikeConfiguration {
    static let minimumNames = 30
    static let recognitionTimeoutSeconds = 60.0
    static let defaultLocale = "en-GB"
}

struct CorpusEntry: Codable, Sendable {
    let id: String
    let expected: String
    let audio: String
}

enum SpikeError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case .invalid(let reason): return reason
        }
    }
}

enum Corpus {
    static func load(_ url: URL) throws -> [CorpusEntry] {
        let entries = try JSONDecoder().decode([CorpusEntry].self, from: Data(contentsOf: url))
        try validate(entries, minimum: SpikeConfiguration.minimumNames)
        for entry in entries {
            let audio = audioURL(entry, relativeTo: url)
            guard FileManager.default.fileExists(atPath: audio.path) else {
                throw SpikeError.invalid("Missing audio for corpus id \(entry.id)")
            }
        }
        return entries
    }

    static func validate(_ entries: [CorpusEntry], minimum: Int) throws {
        guard entries.count >= minimum else {
            throw SpikeError.invalid("Expected at least \(minimum) real names; got \(entries.count)")
        }
        guard Set(entries.map(\.id)).count == entries.count else {
            throw SpikeError.invalid("Corpus ids must be unique")
        }
        let names = entries.map { normalized($0.expected) }
        guard names.allSatisfy({ !$0.isEmpty }), Set(names).count == names.count else {
            throw SpikeError.invalid("Corpus must contain distinct, nonempty names")
        }
        guard entries.allSatisfy({ !$0.id.isEmpty && !$0.audio.isEmpty }) else {
            throw SpikeError.invalid("Corpus ids and audio paths must be nonempty")
        }
    }

    static func audioURL(_ entry: CorpusEntry, relativeTo manifest: URL) -> URL {
        if entry.audio.hasPrefix("/") { return URL(fileURLWithPath: entry.audio) }
        return manifest.deletingLastPathComponent().appendingPathComponent(entry.audio)
    }

    static func normalized(_ text: String) -> String {
        text.lowercased().unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? String($0) : " "
        }.joined().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
