import Foundation

public enum VoiceCommand: Sendable, Equatable {
    case showLastTask
    case show(query: String)
    case showNeedsYou
    case describeWorking
    case cancel
    /// An unsupported composer request; the router must not send its text to another app.
    case dictate(target: String)
}

/// Closed navigation grammar. Fillers are removed at command boundaries, never from a task's name.
public enum CommandParser {
    private static let fillers: Set<String> = ["uh", "um", "please"]
    private static let punctuation = CharacterSet(charactersIn: ",.!?:")
    private static let lastTaskPhrases: Set<String> = ["show the task", "show last task", "open last task", "open the last task", "open last task task", "show it", "open it", "go there"]
    private static let waitingPhrases: Set<String> = ["what's waiting", "what is waiting", "show needs you"]
    private static let workingPhrases: Set<String> = ["what's working", "what is working"]
    private static let cancelPhrases: Set<String> = ["cancel", "stop", "never mind"]

    public static func parse(_ transcript: String) -> VoiceCommand? {
        var words = transcript.split(whereSeparator: \.isWhitespace).map(String.init)
        trimLeadingFillers(&words)
        if words.first.map(normalized) == "porter" {
            words.removeFirst()
            trimLeadingFillers(&words)
        }
        trimTrailingFillers(&words)
        let phrase = words.map(normalized).joined(separator: " ")
        if lastTaskPhrases.contains(phrase) { return .showLastTask }
        if waitingPhrases.contains(phrase) { return .showNeedsYou }
        if workingPhrases.contains(phrase) { return .describeWorking }
        if cancelPhrases.contains(phrase) { return .cancel }
        return namedCommand(words)
    }

    private static func namedCommand(_ words: [String]) -> VoiceCommand? {
        guard let first = words.first.map(normalized) else { return nil }
        if first == "show" || first == "open" {
            let query = target(in: words, dropping: 1)
            return query.isEmpty ? nil : .show(query: query)
        }
        if first == "reply", words.dropFirst().first.map(normalized) == "to" {
            let query = target(in: words, dropping: 2)
            return query.isEmpty ? nil : .dictate(target: query)
        }
        return nil
    }

    private static func target(in words: [String], dropping count: Int) -> String {
        var phrase = words.dropFirst(count).joined(separator: " ")
        while let last = phrase.unicodeScalars.last, punctuation.contains(last) { phrase.removeLast() }
        return phrase
    }

    private static func normalized(_ word: String) -> String {
        word.lowercased().replacingOccurrences(of: "’", with: "'").trimmingCharacters(in: punctuation)
    }

    private static func trimLeadingFillers(_ words: inout [String]) {
        while let first = words.first, fillers.contains(normalized(first)) { words.removeFirst() }
    }

    private static func trimTrailingFillers(_ words: inout [String]) {
        while let last = words.last, fillers.contains(normalized(last)) { words.removeLast() }
    }
}
