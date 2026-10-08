import CoreGraphics
import Foundation

/// Where the panel lives. Stored as plain preferences; no conversation data.
public struct PanelSettings: Equatable, Sendable {
    public static let defaultAnchor: CGFloat = 0.5
    static let edgeKey = "porter.panel.edge"
    static let anchorKey = "porter.panel.anchor"

    public var edge: PanelEdge
    /// Vertical centre as a fraction of the visible screen height, measured from the top.
    public var anchor: CGFloat

    public init(edge: PanelEdge = .right, anchor: CGFloat = PanelSettings.defaultAnchor) {
        self.edge = edge
        self.anchor = min(max(anchor, 0), 1)
    }

    public static func load(from defaults: UserDefaults) -> PanelSettings {
        let edge = defaults.string(forKey: edgeKey).flatMap(PanelEdge.init(rawValue:)) ?? .right
        let stored = defaults.object(forKey: anchorKey) as? Double
        return PanelSettings(edge: edge, anchor: stored.map { CGFloat($0) } ?? defaultAnchor)
    }

    public func save(to defaults: UserDefaults) {
        defaults.set(edge.rawValue, forKey: Self.edgeKey)
        defaults.set(Double(anchor), forKey: Self.anchorKey)
    }
}
