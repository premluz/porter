import ConversationCore
import Foundation

public struct CompletionBatch: Sendable, Equatable {
    public let kind: TurnEndKind
    public let completions: [Completion]

    fileprivate init(kind: TurnEndKind, completions: [Completion]) {
        self.kind = kind
        self.completions = completions
    }
}

/// The deadline belongs to the first event; arrivals cannot keep postponing an announcement.
public struct CompletionCoalescer: Sendable {
    public static let defaultWindow: TimeInterval = 0.75
    public let window: TimeInterval
    public private(set) var nextFlushAt: Date?
    private var pending: [Completion] = []

    public init(window: TimeInterval = defaultWindow) {
        precondition(window.isFinite && window > 0, "Completion coalescing window must be positive and finite")
        self.window = window
    }

    public mutating func append(_ events: [Completion], now: Date) -> [CompletionBatch] {
        let ready = flush(now: now)
        guard !events.isEmpty else { return ready }
        if nextFlushAt == nil { nextFlushAt = now.addingTimeInterval(window) }
        for event in events { enqueue(event) }
        return ready
    }

    public mutating func flush(now: Date) -> [CompletionBatch] {
        guard let deadline = nextFlushAt, now >= deadline else { return [] }
        let batches = [TurnEndKind.completed, .interrupted].compactMap { kind -> CompletionBatch? in
            let events = pending.filter { $0.end.kind == kind }
            return events.isEmpty ? nil : CompletionBatch(kind: kind, completions: events)
        }
        pending.removeAll(keepingCapacity: true)
        nextFlushAt = nil
        return batches
    }

    private mutating func enqueue(_ event: Completion) {
        guard let index = pending.firstIndex(where: { $0.id == event.id }) else {
            pending.append(event)
            return
        }
        if event.end.at > pending[index].end.at { pending[index] = event }
    }
}
