import Foundation

public enum VoiceCommandMatch: Sendable, Equatable {
    case single(PanelItem)
    case multiple(query: String, items: [PanelItem])
    case none(query: String)
}

/// Call with the unfiltered panel's navigable items so visibility and recovery behave like a click.
public enum VoiceCommandMatcher {
    public static func match(query: String, in items: [PanelItem]) -> VoiceCommandMatch {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none(query: query) }
        let matches = items.filter { PanelBuilder.matches($0, query: query) }
        switch matches.count {
        case 0: return .none(query: query)
        case 1: return .single(matches[0])
        default: return .multiple(query: query, items: matches)
        }
    }
}
