import ConversationCore
import Foundation
import PorterPanelModel

public enum SpeechTemplates {
    public static let titleLimit = 80
    public static let projectLimit = 40
    public static let previewText = "Claude has completed a task"

    public static func text(for batch: CompletionBatch) -> String? {
        text(for: batch.completions, kind: batch.kind)
    }

    static func text(for events: [Completion], kind: TurnEndKind) -> String? {
        guard let event = events.first else { return nil }
        if events.count > 1 {
            if kind == .completed, let name = sharedAssistant(events) { return "\(name) has completed \(events.count) tasks" }
            return kind == .completed ? "\(events.count) tasks completed" : "\(events.count) tasks were interrupted"
        }
        let title = clean(event.title, limit: titleLimit)
        let spokenTitle = title.isEmpty ? "Untitled task" : title
        if kind == .interrupted { return "\(spokenTitle) was interrupted" }
        if let assistant = assistantName(event.provider) { return "\(assistant) has completed a task" }
        return "Task completed: \(spokenTitle)"
    }

    private static func assistantName(_ provider: String) -> String? {
        switch ProviderNames.brand(for: provider) {
        case .claude: "Claude"
        case .chatgpt: "Chat GPT"
        case .other: nil
        }
    }

    private static func sharedAssistant(_ events: [Completion]) -> String? {
        guard let first = events.first.flatMap({ assistantName($0.provider) }),
              events.allSatisfy({ assistantName($0.provider) == first }) else { return nil }
        return first
    }

    static func waiting(title: String, projectName: String?) -> String {
        let title = clean(title, limit: titleLimit)
        let project = clean(projectName ?? "", limit: projectLimit)
        let spokenTitle = title.isEmpty ? "Untitled task" : title
        let context = project.isEmpty ? "" : ", in \(project)"
        return "\(spokenTitle) needs you\(context)"
    }

    public static func clean(_ text: String, limit: Int) -> String {
        precondition(limit > 0, "Spoken metadata limit must be positive")
        let words = String(text.map { $0.isLetter || $0.isNumber || $0.isWhitespace ? $0 : " " })
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(words.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
