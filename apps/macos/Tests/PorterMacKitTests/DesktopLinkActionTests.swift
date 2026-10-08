import BridgeTransport
import ConversationCore
import Foundation
import PorterPanelModel
import PorterStore
import Testing
@testable import PorterMacKit

@MainActor
@Suite("Desktop app link")
struct DesktopLinkActionTests {
    @Test("the selected Claude chat opens through the documented link, with an honest notice")
    func opensSelected() async throws {
        let harness = try Harness(rows: [Harness.row("32d0b096-f463-85b5-a77f-1b7fd27d93d8")])
        await harness.model.refresh()
        harness.model.paneVisibilityChanged(visible: true)
        harness.model.openSelectedInDesktopApp()
        #expect(harness.performer.desktopOpened.map(\.absoluteString) == ["claude://claude.ai/chat/32d0b096-f463-85b5-a77f-1b7fd27d93d8"])
        #expect(harness.model.notice?.contains("can't see which account") == true)
    }

    @Test("nothing is handed to the system for any link outside the documented shape")
    func refusesOtherLinks() async throws {
        let harness = try Harness(rows: [Harness.row("a")])
        for text in ["claude://claude.ai/new?q=hi", "https://claude.ai/chat/a", "file:///etc/hosts", "claude://code/new"] {
            harness.model.openInDesktopApp(text)
        }
        #expect(harness.performer.desktopOpened.isEmpty)
        #expect(harness.model.problem != nil)
    }

    @Test("moving the selection clears the notice")
    func noticeClears() async throws {
        let harness = try Harness(rows: [Harness.row("a"), Harness.row("b", title: "Other")])
        await harness.model.refresh()
        harness.model.paneVisibilityChanged(visible: true)
        harness.model.openSelectedInDesktopApp()
        #expect(harness.model.notice != nil)
        harness.model.moveSelection(down: true)
        #expect(harness.model.notice == nil)
    }
}
