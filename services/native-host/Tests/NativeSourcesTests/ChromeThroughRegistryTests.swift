import BridgeTransport
import ConversationCore
import Foundation
import Testing
@testable import NativeSources

@Suite("The scripted Chrome connector inside the registry")
struct ChromeThroughRegistryTests {
    private func waitForRows(_ service: RegistryService, where condition: ([DestinationRow]) -> Bool) -> [DestinationRow] {
        for _ in 0..<200 where !condition(service.listing().rows) { Thread.sleep(forTimeInterval: 0.02) }
        return service.listing().rows
    }

    @Test("tabs appear with no profile, follow later changes, and activate through the registry's checks")
    func lifecycle() throws {
        let runner = FakeRunner()
        runner.setList(record(windowId: 900, tab: 1, url: "https://claude.ai/chat/a", title: "Alpha - Claude"))
        let service = RegistryService(deviceId: UUID(), activationTimeout: 2, log: { _ in }, focusApplication: { "stubbed" })
        let connector = ChromeScriptingConnector(
            installationId: UUID(), runner: runner, pollInterval: .milliseconds(20), isRunning: { true }
        )
        let session = try service.attach(connector)
        defer { session.stop() }

        let first = waitForRows(service) { $0.count == 1 }
        #expect(first.first?.title == "Alpha" && first.first?.profileAlias == nil)
        #expect(service.listing().connectors.first?.providerType == .chromeScripting)

        // A new tab appears without anything asking for a snapshot: the poll notices and reports it.
        runner.setList(
            record(windowId: 900, tab: 1, url: "https://claude.ai/chat/a", title: "Alpha - Claude")
                + record(windowId: 900, position: 2, tab: 2, url: "https://claude.ai/chat/b", title: "Beta - Claude")
        )
        let both = waitForRows(service) { $0.count == 2 }
        #expect(Set(both.map(\.title)) == ["Alpha", "Beta"])

        let beta = try #require(both.first { $0.title == "Beta" })
        let report = service.activate(destinationId: beta.destinationId, expectedRevision: beta.revision)
        #expect(report.outcome == .activated)
        #expect(runner.scripts.last?.arguments == ["900", "2"])
    }
}
