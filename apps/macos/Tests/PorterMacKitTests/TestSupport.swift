import BridgeTransport
import ConversationCore
import Foundation
import PorterPanelModel
import PorterStore
import Testing
@testable import PorterMacKit

@MainActor
final class RecordingPerformer: RecoveryPerformer {
    var opened: [URL] = []
    var launched = 0

    var desktopOpened: [URL] = []
    var copied: [String] = []

    func openInDefaultBrowser(_ url: URL) { opened.append(url) }
    func openInDesktopApp(_ url: URL) { desktopOpened.append(url) }
    func copyToPasteboard(_ text: String) { copied.append(text) }
    func launchBrowser() { launched += 1 }
}

/// A source whose single route answers with whatever outcome the test sets.
final class ScriptedSource: DestinationSource, @unchecked Sendable {
    // Test-only double mutated from the main actor between awaits; no concurrent access occurs.
    var rows: [DestinationRow]
    var connectors: [ConnectorSummary]
    var outcome: ActivationOutcome = .activated
    private(set) var activations: [(UUID, Int)] = []

    init(rows: [DestinationRow], connectors: [ConnectorSummary]) {
        self.rows = rows
        self.connectors = connectors
    }

    func listing() -> RegistryListing { RegistryListing(connectors: connectors, rows: rows) }
    func statuses() -> [UUID: DestinationStatus] { [:] }
    func setChangeHandler(_ handler: @escaping @Sendable () -> Void) {}

    func activate(destinationId: UUID, revision: Int) async -> ActivationReport {
        activations.append((destinationId, revision))
        return ActivationReport(outcome: outcome, appActivation: nil)
    }
}

@MainActor
struct Harness {
    let model: AppModel
    let performer = RecordingPerformer()
    let source: ScriptedSource
    let store: PreferenceStore

    init(rows: [DestinationRow]) throws {
        source = ScriptedSource(rows: rows, connectors: [Self.connector])
        store = try PreferenceStore(path: PreferenceStore.inMemoryPath, deviceId: UUID())
        model = AppModel(source: source, store: store, performer: performer, clock: { Date(timeIntervalSince1970: 1_791_450_000) })
    }

    static let connector = ConnectorSummary(connectorId: "chrome-a", profileAlias: "Work", reachability: .connected, routeCount: 1)

    static func row(_ chat: String, title: String = "Plan", tab: Int = 1) -> DestinationRow {
        DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: chat, provider: "claude",
            title: title, profileAlias: "Work", connectorId: "chrome-a", reachability: .connected, tabId: tab,
            windowId: 1, url: "https://claude.ai/chat/\(chat)", routeCount: 1
        )
    }
}
