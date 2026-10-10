import CoreGraphics
import Foundation

/// Where the panel lives. Stored as plain preferences; no conversation data.
public struct PanelSettings: Equatable, Sendable {
    public static let defaultAnchor: CGFloat = 0.5
    static let edgeKey = "porter.panel.edge"
    static let anchorKey = "porter.panel.anchor"
    static let modeKey = "porter.panel.mode"
    static let floatXKey = "porter.panel.floatX"
    static let floatYKey = "porter.panel.floatY"

    /// Docked on an edge, or floating free; the edge and anchor are kept while floating so it can dock back where it was.
    public var mode: RestMode
    public var edge: PanelEdge
    /// Vertical centre as a fraction of the visible screen height, measured from the top.
    public var anchor: CGFloat
    /// Where a floating capsule's centre is, as fractions of the visible screen from its top left.
    public var floatCenter: CGPoint

    public init(
        mode: RestMode = .docked, edge: PanelEdge = .right, anchor: CGFloat = PanelSettings.defaultAnchor,
        floatCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)
    ) {
        self.mode = mode
        self.edge = edge
        self.anchor = min(max(anchor, 0), 1)
        self.floatCenter = CGPoint(x: min(max(floatCenter.x, 0), 1), y: min(max(floatCenter.y, 0), 1))
    }

    public static func load(from defaults: UserDefaults) -> PanelSettings {
        let edge = defaults.string(forKey: edgeKey).flatMap(PanelEdge.init(rawValue:)) ?? .right
        let stored = defaults.object(forKey: anchorKey) as? Double
        let mode = defaults.string(forKey: modeKey).flatMap(RestMode.init(rawValue:)) ?? .docked
        let center = CGPoint(
            x: (defaults.object(forKey: floatXKey) as? Double) ?? 0.5, y: (defaults.object(forKey: floatYKey) as? Double) ?? 0.5
        )
        return PanelSettings(mode: mode, edge: edge, anchor: stored.map { CGFloat($0) } ?? defaultAnchor, floatCenter: center)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(edge.rawValue, forKey: Self.edgeKey)
        defaults.set(Double(anchor), forKey: Self.anchorKey)
        defaults.set(mode.rawValue, forKey: Self.modeKey)
        defaults.set(Double(floatCenter.x), forKey: Self.floatXKey)
        defaults.set(Double(floatCenter.y), forKey: Self.floatYKey)
    }
}
