import Foundation

public enum PanelPhase: Sendable, Equatable {
    case collapsed, expanding, expanded, collapsing
}

public enum PanelAnimation: Sendable, Equatable {
    /// `generation` identifies this animation; only its own completion may finish it.
    case toExpanded(generation: Int)
    case toCollapsed(generation: Int)
}

/// Open/close logic with reversal. Starting the opposite move mid-transition reverses from where
/// the panel currently is, and a late completion from the interrupted move is ignored.
public struct PanelStateMachine: Sendable, Equatable {
    public private(set) var phase: PanelPhase = .collapsed
    private var generation = 0

    public init() {}

    public var isExpandedOrOpening: Bool { phase == .expanded || phase == .expanding }

    public mutating func open() -> PanelAnimation? {
        guard !isExpandedOrOpening else { return nil }
        generation += 1
        phase = .expanding
        return .toExpanded(generation: generation)
    }

    public mutating func close() -> PanelAnimation? {
        guard isExpandedOrOpening else { return nil }
        generation += 1
        phase = .collapsing
        return .toCollapsed(generation: generation)
    }

    public mutating func toggle() -> PanelAnimation? {
        isExpandedOrOpening ? close() : open()
    }

    /// Returns true when this completion ended the current animation.
    @discardableResult
    public mutating func finished(_ animation: PanelAnimation) -> Bool {
        switch animation {
        case .toExpanded(let id) where id == generation && phase == .expanding:
            phase = .expanded
            return true
        case .toCollapsed(let id) where id == generation && phase == .collapsing:
            phase = .collapsed
            return true
        default:
            return false
        }
    }
}
