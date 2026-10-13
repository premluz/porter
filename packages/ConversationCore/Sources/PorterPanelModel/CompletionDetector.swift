import ConversationCore
import Foundation

public struct Completion: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let provider: String
    public let projectName: String?
    public let end: TurnEnd

    public init(id: String, title: String, provider: String = "", projectName: String?, end: TurnEnd) {
        self.id = id
        self.title = title
        self.provider = provider
        self.projectName = projectName
        self.end = end
    }
}

/// End markers are evidence only after Porter observed this item working in an earlier update.
public struct CompletionDetector: Sendable {
    private var armedAfter: [String: Date] = [:]
    private var emittedAt: [String: Date] = [:]

    public init() {}

    public mutating func update(items: [PanelItem], now: Date) -> [Completion] {
        let eligible = items.filter { !$0.hidden && $0.isOpenable && $0.status.freshness == .fresh }
        let present = Set(eligible.map(\.id))
        armedAfter = armedAfter.filter { present.contains($0.key) }
        return eligible.compactMap { process($0, now: now) }
    }

    private mutating func process(_ item: PanelItem, now: Date) -> Completion? {
        let previousArm = armedAfter[item.id]
        if let previousArm, let end = item.status.turnEnd,
           end.at > previousArm, end.at > (emittedAt[item.id] ?? .distantPast), end.at <= now {
            emittedAt[item.id] = end.at
            armedAfter[item.id] = item.status.display == .working ? now : nil
            return Completion(id: item.id, title: item.title, provider: item.provider, projectName: item.projectName, end: end)
        }
        if item.status.display == .working {
            if previousArm == nil {
                armedAfter[item.id] = max(now, item.status.turnEndedAt ?? .distantPast)
            }
        } else {
            armedAfter[item.id] = nil
        }
        return nil
    }
}
