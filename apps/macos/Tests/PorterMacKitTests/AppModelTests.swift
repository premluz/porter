import BridgeTransport
import ConversationCore
import Foundation
import PorterPanelModel
import PorterStore
import Testing
@testable import PorterMacKit

@MainActor
@Suite("App model behavior")
struct AppModelTests {
    @Test("Return on a single route hands off and collapses the pane")
    func successfulHandoff() async throws {
        let harness = try Harness(rows: [Harness.row("a")])
        var collapsed = 0
        harness.model.onHandoff = { collapsed += 1 }
        await harness.model.refresh()
        harness.model.paneVisibilityChanged(visible: true)
        await harness.model.activateSelected()
        #expect(collapsed == 1)
        #expect(harness.model.feedback == nil)
        #expect(harness.source.activations.count == 1)
    }

    @Test("a failed open keeps the pane open, explains why, and refreshes")
    func failedOpenKeepsPane() async throws {
        let harness = try Harness(rows: [Harness.row("a")])
        harness.source.outcome = .targetGone
        var collapsed = 0
        harness.model.onHandoff = { collapsed += 1 }
        await harness.model.refresh()
        harness.model.paneVisibilityChanged(visible: true)
        await harness.model.activateSelected()
        #expect(collapsed == 0)
        #expect(harness.model.feedback?.feedback.title == "That tab was closed")
    }

    @Test("two tabs of one chat ask which, and the choice is the one opened")
    func routeChoiceFlow() async throws {
        let first = Harness.row("a", tab: 1)
        let second = Harness.row("a", tab: 2)
        let harness = try Harness(rows: [first, second])
        await harness.model.refresh()
        harness.model.paneVisibilityChanged(visible: true)
        await harness.model.activateSelected()
        #expect(harness.model.routeChoice != nil)
        #expect(harness.source.activations.isEmpty)
        harness.model.moveSelection(down: true)
        await harness.model.confirmRouteChoice()
        #expect(harness.source.activations.first?.0 == second.destinationId)
        #expect(harness.model.routeChoice == nil)
    }

    @Test("Escape unwinds chooser, then feedback, then search, then closes")
    func escapeOrder() async throws {
        let harness = try Harness(rows: [Harness.row("a", tab: 1), Harness.row("a", tab: 2)])
        await harness.model.refresh()
        harness.model.paneVisibilityChanged(visible: true)
        await harness.model.activateSelected()
        #expect(harness.model.escape())
        #expect(harness.model.routeChoice == nil)
        harness.model.query = "pla"
        #expect(harness.model.escape())
        #expect(harness.model.query.isEmpty)
        #expect(!harness.model.escape())
    }

    @Test("pinning persists, survives a closed tab, and unpinning removes it")
    func pinLifecycle() async throws {
        let harness = try Harness(rows: [Harness.row("a")])
        await harness.model.refresh()
        let item = try #require(harness.model.items.first)
        await harness.model.togglePin(item)
        #expect(harness.model.snapshot.pinned.count == 1)
        harness.source.rows = []
        await harness.model.refresh()
        let closed = try #require(harness.model.snapshot.pinned.first)
        #expect(closed.availability == .unavailable(.closed))
        await harness.model.activateSelected()
        harness.model.select(closed)
        await harness.model.activateSelected()
        #expect(harness.model.feedback?.feedback.title == "That tab was closed")
        await harness.model.unpin(closed)
        #expect(harness.model.snapshot.pinned.isEmpty)
    }

    @Test("the saved-link fallback opens only secure addresses, and only when asked")
    func savedLinkFallback() async throws {
        let harness = try Harness(rows: [Harness.row("a")])
        await harness.model.refresh()
        let item = try #require(harness.model.items.first)
        await harness.model.perform(.openSavedLinkInDefaultBrowser(url: "http://example.com/x"), for: item)
        #expect(harness.performer.opened.isEmpty)
        #expect(harness.model.problem != nil)
        await harness.model.perform(.openSavedLinkInDefaultBrowser(url: "https://claude.ai/chat/a"), for: item)
        #expect(harness.performer.opened.map(\.absoluteString) == ["https://claude.ai/chat/a"])
    }

    @Test("an open pane keeps item order while new items arrive at the end")
    func orderFrozenWhileOpen() async throws {
        let harness = try Harness(rows: [Harness.row("b", title: "Beta"), Harness.row("c", title: "Gamma")])
        await harness.model.refresh()
        harness.model.paneVisibilityChanged(visible: true)
        let before = harness.model.items.map(\.title)
        harness.source.rows.append(Harness.row("a", title: "Alpha"))
        await harness.model.refresh()
        #expect(harness.model.items.map(\.title) == before + ["Alpha"])
        harness.model.paneVisibilityChanged(visible: false)
        await harness.model.refresh()
        #expect(harness.model.items.first?.title == "Alpha")
    }

    @Test("typing filters and selects the first match; hidden items can be shown")
    func searchAndHidden() async throws {
        let harness = try Harness(rows: [Harness.row("a", title: "Release"), Harness.row("b", title: "Budget")])
        await harness.model.refresh()
        harness.model.query = "bud"
        #expect(harness.model.items.map(\.title) == ["Budget"])
        #expect(harness.model.selectedItem?.title == "Budget")
        harness.model.query = ""
        let item = try #require(harness.model.items.first { $0.title == "Release" })
        await harness.model.toggleHidden(item)
        #expect(harness.model.items.map(\.title) == ["Budget"])
        harness.model.toggleShowHidden()
        #expect(harness.model.items.count == 2)
    }

    @Test("the fixture source covers every state the panel can show")
    func fixtureCoversStates() async throws {
        let store = try PreferenceStore(path: PreferenceStore.inMemoryPath, deviceId: UUID())
        try await SampleData.seedPins(into: store, at: Date())
        let model = AppModel(source: FixtureSource(), store: store, performer: RecordingPerformer())
        await model.refresh()
        let all = model.items
        #expect(all.contains { $0.isAmbiguous })
        #expect(all.contains { $0.sharesTitle })
        #expect(all.contains { $0.availability == .unavailable(.closed) })
        #expect(all.contains { $0.availability == .unavailable(.sourceOffline) })
        let labels = Set(all.map { StatusPresentation.label(for: $0.status) })
        #expect(labels.isSuperset(of: ["Working", "Needs you", "New response", "Unknown"]))
        #expect(labels.contains("Last seen working 15 min ago"))
    }
}
