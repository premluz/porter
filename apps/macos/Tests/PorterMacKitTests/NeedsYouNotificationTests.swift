import ConversationCore
import Foundation
import PorterPanelModel
import Testing
@testable import PorterMacKit

@MainActor
final class RecordingNotifier: NeedsYouNotifying {
    private(set) var notified: [String] = []
    private(set) var withdrawn: [String] = []
    func notify(_ item: PanelItem) { notified.append(item.title) }
    func withdraw(ids: Set<String>) { withdrawn += ids.sorted() }
}

@MainActor
@Suite("A chat that starts waiting on the person is announced once")
struct NeedsYouNotificationTests {
    private func waiting(_ row: DestinationRow) -> DestinationStatus {
        let now = Date(timeIntervalSince1970: 1_791_450_000)
        let observation = StatusObservation(
            id: UUID(), destinationId: row.destinationId, activity: .idle, attention: .needsUser, evidenceKind: .providerEvent,
            observedAt: now, receivedAt: now, expiresAt: now.addingTimeInterval(1_800), sequence: 1, connectionEpoch: "hook", adapterVersion: "0.1.0"
        )
        return DestinationStatus(display: .needsUser, freshness: .fresh, reachability: .connected, lastKnown: observation)
    }

    @Test("one notice when it starts waiting, none for the same one on later refreshes, taken down when it stops, and again if it waits again")
    func lifecycle() async throws {
        let row = Harness.row("a", title: "Needs an answer")
        let harness = try Harness(rows: [row])
        let notifier = RecordingNotifier()
        harness.model.notifier = notifier
        await harness.model.refresh()
        #expect(notifier.notified.isEmpty)

        harness.source.statusMap[row.destinationId] = waiting(row)
        await harness.model.refresh()
        await harness.model.refresh()
        #expect(notifier.notified == ["Needs an answer"] && harness.model.snapshot.needsYou.count == 1)

        harness.source.statusMap = [:]
        await harness.model.refresh()
        #expect(notifier.withdrawn.count == 1 && harness.model.snapshot.needsYou.isEmpty)

        harness.source.statusMap[row.destinationId] = waiting(row)
        await harness.model.refresh()
        #expect(notifier.notified == ["Needs an answer", "Needs an answer"])
    }

    @Test("with the pane open the person is looking at it, so no notice is posted, and it is not posted later either")
    func quietWhileOpen() async throws {
        let row = Harness.row("a", title: "Needs an answer")
        let harness = try Harness(rows: [row])
        let notifier = RecordingNotifier()
        harness.model.notifier = notifier
        await harness.model.refresh()
        harness.model.paneVisibilityChanged(visible: true)
        harness.source.statusMap[row.destinationId] = waiting(row)
        await harness.model.refresh()
        harness.model.paneVisibilityChanged(visible: false)
        await harness.model.refresh()
        #expect(notifier.notified.isEmpty)
    }

    @Test("the setup row offers to allow notifications, or to open the settings when blocked, and is absent unbundled")
    func setupRow() {
        func row(_ state: NotificationState?) -> SetupRow? {
            SetupChecklist.sections(for: SetupInputs(chrome: .ready, notifications: state)).flatMap(\.rows).first { $0.id == "notifications" }
        }
        #expect(row(.notAvailable) == nil && row(nil) == nil)
        #expect(row(.notAsked)?.action == .requestNotifications)
        #expect(row(.denied)?.action == .openNotificationSettings)
        #expect(row(.allowed)?.state == .ready)
    }
}
