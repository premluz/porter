import BridgeTransport
import ConversationCore
import Foundation
import PorterPanelModel
import PorterStore

extension AppModel {
    /// A chat that starts waiting is announced once, unless the pane is open and the person is looking at it; one that
    /// stops waiting has its notice taken down, and is announced again if it waits again later.
    func announceWaiting() {
        let waiting = Dictionary(snapshot.needsYou.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let started = Set(waiting.keys).subtracting(announcedWaiting)
        let ended = announcedWaiting.subtracting(waiting.keys)
        announcedWaiting = Set(waiting.keys)
        if !isPaneVisible { for id in started.sorted() { if let item = waiting[id] {
            if voiceSettings?.waitingNotices != false { notifier?.notify(item) }
            speechAnnouncer?.announceWaiting(item)
        } } }
        notifier?.withdraw(ids: ended)
    }

    func queryChanged() {
        feedback = nil
        routeChoice = nil
        rebuild()
        selection.reset(to: items)
    }

    func rebuild() {
        let previous = items
        let statuses = source.statuses()
        let observed = PanelBuilder.build(PanelInputs(
            rows: listing.rows, connectors: listing.connectors, records: records, statuses: statuses, now: clock()
        ))
        observedItems = observed.navigable(showingOlder: true)
        observeCompletions()
        snapshot = PanelBuilder.build(PanelInputs(
            rows: listing.rows, connectors: listing.connectors, records: records, statuses: statuses,
            query: query, showHidden: showHidden, frozenOrder: frozenOrder, now: clock()
        ))
        selection.reconcile(with: items, previous: previous)
        announceWaiting()
        onContentChanged()
    }

    func refreshStoredMetadata() async throws(StoreError) {
        for item in snapshot.pinned where item.isOpenable {
            try await store.refresh(item.snapshot, at: clock())
        }
        records = try await store.all()
    }
}
