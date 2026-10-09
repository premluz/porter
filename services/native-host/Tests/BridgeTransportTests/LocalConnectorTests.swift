import ConversationCore
import Foundation
import Synchronization
import Testing
@testable import BridgeTransport

private final class ScriptedHost: HostConnector {
    let kind = ConnectorKind.chrome
    let installationId = UUID()
    let profileAlias: String? = nil
    let adapterVersions = ProviderRecognizers.adapterVersions
    let outcome: ActivationOutcome
    let tabs = Mutex<[TabReport]>([])
    let activations = Mutex<[ActivateRequestPayload]>([])
    private let signal = AsyncStream<Void>.makeStream()

    init(tabs: [TabReport], outcome: ActivationOutcome = .activated) {
        self.outcome = outcome
        self.tabs.withLock { $0 = tabs }
    }

    func snapshot() async throws -> InventorySnapshotPayload { InventorySnapshotPayload(tabs: tabs.withLock { $0 }) }

    func activate(_ request: ActivateRequestPayload) async -> ActivationOutcome {
        activations.withLock { $0.append(request) }
        return outcome
    }

    func changes() -> AsyncStream<Void> { signal.stream }

    func change(to newTabs: [TabReport]) {
        tabs.withLock { $0 = newTabs }
        signal.continuation.yield()
    }
}

private func tab(_ id: Int, _ chat: String, title: String = "Plan") -> TabReport {
    TabReport(tabId: id, windowId: 1, provider: "claude", providerConversationId: chat, title: title, canonicalUrl: "https://claude.ai/chat/\(chat)")
}

@Suite("An in-app connector joins the registry like any other")
struct LocalConnectorTests {
    private func service() -> RegistryService {
        RegistryService(deviceId: UUID(), activationTimeout: 2, log: { _ in }, focusApplication: { "stubbed" })
    }

    private func waitForRows(_ service: RegistryService, count: Int) -> [DestinationRow] {
        for _ in 0..<150 where service.listing().rows.count != count { Thread.sleep(forTimeInterval: 0.02) }
        return service.listing().rows
    }

    @Test("its snapshot becomes destinations, a later change updates them, and stopping leaves them unreachable")
    func inventoryLifecycle() throws {
        let service = service()
        let host = ScriptedHost(tabs: [tab(1, "a", title: "Alpha")])
        let session = try service.attach(host)
        #expect(waitForRows(service, count: 1).first?.title == "Alpha")

        host.change(to: [tab(1, "a", title: "Alpha"), tab(2, "b", title: "Beta")])
        #expect(Set(waitForRows(service, count: 2).map(\.title)) == ["Alpha", "Beta"])

        // A stopped connector leaves its rows listed but no longer reachable, as a dropped socket does.
        session.stop()
        for _ in 0..<150 where service.listing().rows.contains(where: { $0.reachability == .connected }) {
            Thread.sleep(forTimeInterval: 0.02)
        }
        #expect(service.listing().rows.count == 2 && service.listing().rows.allSatisfy { $0.reachability == .disconnected })
    }

    @Test("an activation reaches the host with the registry's checks and its answer comes back")
    func activation() throws {
        let service = service()
        let host = ScriptedHost(tabs: [tab(7, "a")])
        let session = try service.attach(host)
        defer { session.stop() }
        let row = try #require(waitForRows(service, count: 1).first)

        let report = service.activate(destinationId: row.destinationId, expectedRevision: row.revision)
        #expect(report.outcome == .activated)
        let request = try #require(host.activations.withLock { $0.first })
        #expect(request.tabId == 7 && request.expectedConversationId == "a" && request.expectedProvider == "claude")
    }

    @Test("a host that cannot reach its target reports why, and the registry passes it on")
    func failedActivation() throws {
        let service = service()
        let host = ScriptedHost(tabs: [tab(1, "a")], outcome: .targetGone)
        let session = try service.attach(host)
        defer { session.stop() }
        let row = try #require(waitForRows(service, count: 1).first)
        #expect(service.activate(destinationId: row.destinationId, expectedRevision: row.revision).outcome == .targetGone)
    }

    @Test("two connectors with the same installation are refused, as on the socket")
    func duplicateInstallation() throws {
        let service = service()
        let host = ScriptedHost(tabs: [tab(1, "a")])
        let first = try service.attach(host)
        defer { first.stop() }
        _ = waitForRows(service, count: 1)
        let second = try service.attach(host)
        defer { second.stop() }
        Thread.sleep(forTimeInterval: 0.3)
        #expect(service.listing().connectors.count == 1)
    }
}
