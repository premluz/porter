import BridgeTransport
import ConversationCore
import Foundation
import Testing
@testable import NativeSources

private let claudeBundle = "com.anthropic.claudefordesktop"

private func claudeTree(_ press: @escaping @Sendable (String) -> Void) -> FakeNode {
    fakeWindow([
        side("AXRadioButton", "Claude"),
        side("AXButton", "Yesterday"),
        side("AXGroup", "", onPress: press, children: [side("AXStaticText", "Chat A", onPress: press)]),
        side("AXStaticText", "Chat B", onPress: press),
        side("AXStaticText", "Chat A", onPress: press),
    ])
}

private func connector(_ fake: FakeAccessibility) -> DesktopAppConnector {
    DesktopAppConnector(
        installationId: UUID(), adapters: [ClaudeDesktopAdapter()], accessibility: fake, pollInterval: .milliseconds(20)
    )
}

private func request(_ title: String, ordinal: Int, bundle: String = claudeBundle) throws -> ActivateRequestPayload {
    let json = #"{"requestId":"\#(UUID())","destinationId":"\#(UUID())","destinationRevision":1,"expectedProvider":"claude-desktop","expectedConversationId":"x","app":{"bundleId":"\#(bundle)","expectedTitle":"\#(title)","ordinal":\#(ordinal)}}"#
    return try ContractCoding.decoder().decode(ActivateRequestPayload.self, from: Data(json.utf8))
}

@Suite("The desktop-app connector")
struct DesktopConnectorTests {
    @Test("entries become reports with a stable digest id, an ordinal among equal titles, and the app's bundle")
    func reports() async throws {
        let source = connector(FakeAccessibility(tree: claudeTree))
        let entries = try #require(try await source.snapshot().appEntries)
        #expect(entries.map(\.title) == ["Chat A", "Chat B", "Chat A"])
        #expect(entries.map(\.ordinal) == [0, 0, 1])
        #expect(entries.map(\.position) == [0, 1, 2])
        #expect(entries[0].providerConversationId != entries[2].providerConversationId)
        #expect(entries[0].providerConversationId.hasSuffix("-0") && entries[2].providerConversationId.hasSuffix("-1"))
        #expect(entries.allSatisfy { $0.provider == "claude-desktop" && $0.bundleId == claudeBundle })
        #expect(try await source.snapshot().appEntries == entries)
        #expect(source.health["claude-desktop"] == .ready)
    }

    @Test("without the Accessibility permission nothing is read and the state says so")
    func notTrusted() async throws {
        let fake = FakeAccessibility(tree: claudeTree)
        fake.set(trusted: false)
        let source = connector(fake)
        #expect(try await source.snapshot().appEntries == [])
        #expect(source.health["claude-desktop"] == .permissionDenied)
        #expect(await source.activate(try request("Chat B", ordinal: 0)) == .permissionDenied)
    }

    @Test("an app that is not running is never asked and has no entries")
    func notRunning() async throws {
        let fake = FakeAccessibility(tree: claudeTree)
        fake.set(running: false)
        let source = connector(fake)
        #expect(try await source.snapshot().appEntries == [])
        #expect(source.health["claude-desktop"] == .notRunning)
    }

    @Test("a window that cannot be read keeps the last list and says why; a closed sidebar does the same")
    func unreadableKeepsLast() async throws {
        let fake = FakeAccessibility(tree: claudeTree)
        let source = connector(fake)
        let before = try #require(try await source.snapshot().appEntries)
        fake.set(hasWindow: false)
        #expect(try await source.snapshot().appEntries == before)
        guard case .failed(let reason) = source.health["claude-desktop"] else { Issue.record("expected failed"); return }
        #expect(reason.contains("desktop"))
    }

    @Test("an entry is pressed only when its title and position still match, and the app is brought forward")
    func activation() async throws {
        let fake = FakeAccessibility(tree: claudeTree)
        let source = connector(fake)
        #expect(await source.activate(try request("Chat A", ordinal: 1)) == .activated)
        #expect(fake.presses.count == 1 && fake.forwarded == [claudeBundle])
        #expect(await source.activate(try request("Gone", ordinal: 0)) == .targetGone)
        #expect(await source.activate(try request("Chat B", ordinal: 1)) == .targetChanged)
        #expect(await source.activate(try request("Chat B", ordinal: 0, bundle: "com.example.Other")) == .unsupported)
        #expect(fake.presses.count == 1)
    }

    @Test("a closed app cannot be activated")
    func offline() async throws {
        let fake = FakeAccessibility(tree: claudeTree)
        fake.set(running: false)
        #expect(await connector(fake).activate(try request("Chat B", ordinal: 0)) == .connectorOffline)
    }
}

@Suite("The desktop-app connector inside the registry")
struct DesktopThroughRegistryTests {
    @Test("chats appear as routes with no profile and open through the registry's checks")
    func lifecycle() throws {
        let fake = FakeAccessibility(tree: claudeTree)
        let service = RegistryService(deviceId: UUID(), activationTimeout: 2, log: { _ in }, focusApplication: { "stubbed" })
        let session = try service.attach(connector(fake))
        defer { session.stop() }

        func rows(_ condition: ([DestinationRow]) -> Bool) -> [DestinationRow] {
            for _ in 0..<200 where !condition(service.listing().rows) { Thread.sleep(forTimeInterval: 0.02) }
            return service.listing().rows
        }
        let initial = rows { $0.count == 3 }
        #expect(Set(initial.map(\.title)) == ["Chat A", "Chat B"] && initial.allSatisfy { $0.profileAlias == nil && $0.provider == "claude-desktop" })
        #expect(service.listing().connectors.first?.providerType == .desktopApp)

        let second = try #require(initial.filter { $0.title == "Chat A" }.first { $0.providerConversationId.hasSuffix("-1") })
        let report = service.activate(destinationId: second.destinationId, expectedRevision: second.revision)
        #expect(report.outcome == .activated)
        #expect(fake.presses.count == 1)
    }
}
