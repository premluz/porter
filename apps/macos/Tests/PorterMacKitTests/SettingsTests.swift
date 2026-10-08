import BridgeTransport
import ConversationCore
import Foundation
import PorterPanelModel
import PorterStore
import Testing
@testable import PorterMacKit

@Suite("Panel settings")
struct SettingsTests {
    private func defaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "porter.test.\(UUID().uuidString)"))
    }

    @Test("defaults are right edge, centred")
    func defaultsApply() throws {
        let settings = PanelSettings.load(from: try defaults())
        #expect(settings == PanelSettings(edge: .right, anchor: 0.5))
    }

    @Test("settings round-trip and anchors are clamped")
    func roundTrip() throws {
        let store = try defaults()
        PanelSettings(edge: .left, anchor: 0.25).save(to: store)
        #expect(PanelSettings.load(from: store) == PanelSettings(edge: .left, anchor: 0.25))
        #expect(PanelSettings(anchor: 4).anchor == 1)
        #expect(PanelSettings(anchor: -4).anchor == 0)
    }

    @Test("an unreadable stored edge falls back to the default instead of crashing")
    func badEdge() throws {
        let store = try defaults()
        store.set("top", forKey: PanelSettings.edgeKey)
        #expect(PanelSettings.load(from: store).edge == .right)
    }
}
