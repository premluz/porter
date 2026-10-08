import BridgeTransport
import ConversationCore
import Foundation
import PorterPanelModel
import PorterStore

/// Sample destinations for the Mac panel, from the data shared with the phone app. Nothing here
/// talks to a browser.
public final class FixtureSource: DestinationSource {
    private let entries = SampleData.entries
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    public func listing() -> RegistryListing {
        RegistryListing(connectors: SampleData.connectors, rows: entries.map(\.row))
    }

    public func statuses() -> [UUID: DestinationStatus] {
        let current = now()
        return Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            SampleData.status(of: entry, now: current).map { (entry.row.destinationId, $0) }
        })
    }

    public func activate(destinationId: UUID, revision: Int) async -> ActivationReport {
        let outcome = entries.first { $0.row.destinationId == destinationId }?.outcome ?? .targetGone
        return ActivationReport(outcome: outcome, appActivation: outcome == .activated ? "sample" : nil)
    }

    public func setChangeHandler(_ handler: @escaping @Sendable () -> Void) {}
}
