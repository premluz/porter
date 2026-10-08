import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("Keyboard selection")
struct SelectionTests {
    private func items(_ chats: [String]) -> [PanelItem] {
        Fixture.build(rows: chats.enumerated().map { Fixture.row($1, title: "T\($0)", tab: $0) }).open
    }

    @Test("arrows move within bounds and never wrap")
    func moves() {
        let list = items(["a", "b", "c"])
        var selection = PanelSelection()
        selection.moveUp(in: list)
        #expect(selection.selectedId == list.last?.id)
        selection.moveDown(in: list)
        #expect(selection.selectedId == list.last?.id)
        selection.moveUp(in: list)
        selection.moveUp(in: list)
        selection.moveUp(in: list)
        #expect(selection.selectedId == list.first?.id)
    }

    @Test("first down arrow selects the first item")
    func firstDown() {
        let list = items(["a", "b"])
        var selection = PanelSelection()
        selection.moveDown(in: list)
        #expect(selection.selectedId == list.first?.id)
    }

    @Test("Return on one route activates it; several routes ask; none shows recovery")
    func returnKey() {
        let single = items(["a"])
        var selection = PanelSelection(selectedId: single[0].id)
        guard case .activate(_, let route) = selection.action(in: single) else { Issue.record("expected activate"); return }
        #expect(route.destinationId == single[0].routes[0].destinationId)

        let double = Fixture.build(rows: [Fixture.row("a", tab: 1), Fixture.row("a", tab: 2)]).open
        selection.select(double[0].id)
        #expect(selection.action(in: double) == .chooseRoute(double[0]))

        let closed = Fixture.build(records: [Fixture.record("z")]).pinned
        selection.select(closed[0].id)
        #expect(selection.action(in: closed) == .showRecovery(closed[0]))
        selection.select(nil)
        #expect(selection.action(in: closed) == .nothing)
    }

    @Test("when the list changes the selection stays on the same item")
    func reconcileKeeps() {
        let before = items(["a", "b", "c"])
        var selection = PanelSelection(selectedId: before[1].id)
        selection.reconcile(with: [before[0], before[1]], previous: before)
        #expect(selection.selectedId == before[1].id)
    }

    @Test("when the selected item disappears the nearest one is selected, or none")
    func reconcileGone() {
        let before = items(["a", "b", "c"])
        var selection = PanelSelection(selectedId: before[2].id)
        selection.reconcile(with: [before[0], before[1]], previous: before)
        #expect(selection.selectedId == before[1].id)
        selection.reconcile(with: [], previous: [before[0], before[1]])
        #expect(selection.selectedId == nil)
    }

    @Test("typing resets selection to the first match")
    func resetOnQuery() {
        let list = items(["a", "b"])
        var selection = PanelSelection(selectedId: list[1].id)
        selection.reset(to: list)
        #expect(selection.selectedId == list[0].id)
        selection.reset(to: [])
        #expect(selection.selectedId == nil)
    }
}

@Suite("Messages and labels")
struct PresentationTests {
    private let item = Fixture.build(rows: [Fixture.row("a", title: "Plan", alias: "Work")]).open[0]

    @Test("every activation outcome has feedback, and only success closes the pane")
    func feedbackForEveryOutcome() {
        let outcomes: [ActivationOutcome] = [
            .activated, .targetGone, .targetChanged, .accountChanged, .connectorOffline,
            .permissionDenied, .unsupported, .versionMismatch, .timeout, .failed,
        ]
        for outcome in outcomes {
            let feedback = ActivationFeedbackBuilder.feedback(for: outcome, item: item)
            #expect(!feedback.title.isEmpty)
            #expect(feedback.dismissesPane == (outcome == .activated), "\(outcome)")
            if outcome != .activated { #expect(!feedback.recovery.isEmpty, "\(outcome) needs a next step") }
        }
    }

    @Test("a timeout is never described as a failure to open")
    func timeoutIsHonest() {
        let feedback = ActivationFeedbackBuilder.feedback(for: .timeout, item: item)
        #expect(feedback.detail.contains("may have opened"))
    }

    @Test("the default-browser fallback is offered only with a saved link and is labelled in the action")
    func savedLinkFallback() {
        let gone = ActivationFeedbackBuilder.feedback(for: .targetGone, item: item)
        #expect(gone.recovery.contains(.openSavedLinkInDefaultBrowser(url: "https://claude.ai/chat/a")))
        let noLink = PanelItem(
            key: item.key, title: "Plan", provider: "claude", profileAlias: "Work", canonicalUrl: nil, pinned: false,
            hidden: false, availability: .unavailable(.closed), status: .unknown, sharesTitle: false
        )
        let none = ActivationFeedbackBuilder.feedback(for: .targetGone, item: noLink)
        #expect(!none.recovery.contains { if case .openSavedLinkInDefaultBrowser = $0 { true } else { false } })
    }

    @Test("a Claude chat offers the desktop app as a recovery step; other providers do not")
    func desktopRecovery() {
        let gone = ActivationFeedbackBuilder.feedback(for: .targetGone, item: item)
        #expect(gone.recovery.contains(.openInDesktopApp(url: "claude://claude.ai/chat/a")))
        let other = PanelItem(
            key: item.key, title: "T", provider: "chatgpt", profileAlias: nil, canonicalUrl: nil, pinned: false,
            hidden: false, availability: .unavailable(.closed), status: .unknown, sharesTitle: false
        )
        #expect(other.desktopLink == nil)
        let feedback = ActivationFeedbackBuilder.feedback(for: .targetGone, item: other)
        #expect(!feedback.recovery.contains { if case .openInDesktopApp = $0 { true } else { false } })
    }

    @Test("provider names read as people write them")
    func providerNames() {
        #expect(ProviderNames.display("claude") == "Claude")
        #expect(ProviderNames.display("chatgpt") == "ChatGPT")
        #expect(ProviderNames.display("somethingnew") == "somethingnew")
    }

    @Test("age wording is plain and steps up sensibly")
    func ages() {
        #expect(StatusPresentation.age(seconds: 5) == "just now")
        #expect(StatusPresentation.age(seconds: 120) == "2 min ago")
        #expect(StatusPresentation.age(seconds: 7_200) == "2 h ago")
        #expect(StatusPresentation.age(seconds: 172_800) == "2 d ago")
    }

    @Test("a stale known status reads as last seen, not as live")
    func staleLabel() {
        let stale = ItemStatus(display: .unknown, freshness: .stale, ageSeconds: 300, lastKnown: .working)
        #expect(StatusPresentation.label(for: stale) == "Last seen working 5 min ago")
        let neverSeen = ItemStatus(display: .unknown, freshness: .stale, ageSeconds: 300)
        #expect(StatusPresentation.label(for: neverSeen) == "Unknown")
        let notLive = ItemStatus(display: .working, freshness: .stale, ageSeconds: 300, lastKnown: .working)
        #expect(!StatusPresentation.label(for: notLive).hasPrefix("Working"))
    }

    @Test("the VoiceOver label includes title, provider, profile, status and availability")
    func accessibility() {
        let label = StatusPresentation.accessibilityLabel(for: item)
        #expect(label == "Plan, Claude, profile Work, Unknown")
        let double = Fixture.build(rows: [Fixture.row("a", tab: 1), Fixture.row("a", tab: 2)]).open[0]
        #expect(StatusPresentation.accessibilityLabel(for: double).contains("open in 2 tabs, choose one"))
        let offline = Fixture.build(connectors: [], records: [Fixture.record("z")]).pinned[0]
        let spoken = StatusPresentation.accessibilityLabel(for: offline)
        #expect(spoken.contains("browser not connected") && spoken.contains("pinned"))
    }
}
