import ConversationCore
import Foundation
import Observation
import PorterPanelModel
import PorterStore

/// What the phone shows. Until sync exists (ADR-003, TASK-030) this is built from the shared
/// sample data, and the screen says so; the phone never claims live status it does not have.
@MainActor
@Observable
final class PhoneModel {
    private(set) var snapshot = PanelBuilder.build(PanelInputs(rows: [], connectors: [], records: [], now: Date()))
    private(set) var problem: String?
    var query = "" {
        didSet { if query != oldValue { Task { await load() } } }
    }

    let isSampleData = true

    func load() async {
        do {
            let store = try PreferenceStore(path: PreferenceStore.inMemoryPath, deviceId: UUID())
            try await SampleData.seedPins(into: store, at: Date())
            let now = Date()
            snapshot = PanelBuilder.build(PanelInputs(
                rows: SampleData.entries.map(\.row), connectors: SampleData.connectors, records: try await store.all(),
                statuses: Dictionary(uniqueKeysWithValues: SampleData.entries.compactMap { entry in
                    SampleData.status(of: entry, now: now).map { (entry.row.destinationId, $0) }
                }),
                query: query, now: now
            ))
            problem = nil
        } catch {
            problem = "Could not load conversations: \(error)"
        }
    }
}
