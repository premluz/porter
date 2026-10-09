import Foundation
import Synchronization
import Testing
@testable import NativeSources

/// Trees shaped like the ones seen on the real apps, with placeholder titles.
private func claudeWindow(sidebarOpen: Bool = true, press: @escaping @Sendable (String) -> Void = { _ in }) -> FakeNode {
    var nodes = [
        side("AXButton", "Hide sidebar"), side("AXRadioButton", "Claude"), side("AXRadioButton", "Code"),
        centre("AXStaticText", "A message that must never be read"),
    ]
    if sidebarOpen {
        nodes += [
            side("AXButton", "Toggle sessions for Project One"), side("AXStaticText", "Project One"),
            side("AXStaticText", "View all"),
            side("AXButton", "Yesterday"), side("AXGroup", "", onPress: press, children: [side("AXStaticText", "Chat A")]),
            side("AXButton", "Older"),
            side("AXGroup", "", onPress: press, children: [side("AXStaticText", "Chat B")]),
            side("AXGroup", "", onPress: press, children: [side("AXStaticText", "Chat A")]),
            side("AXStaticText", "Untitled"),
        ]
    }
    return fakeWindow(nodes)
}

private func chatgptWindow(recents: Bool = true, press: @escaping @Sendable (String) -> Void = { _ in }) -> FakeNode {
    var nodes = [
        side("AXButton", "Home"), side("AXButton", "Projects"),
        side("AXButton", "Portfolio"), side("AXStaticText", "Portfolio"), side("AXButton", "New local chat in Portfolio"),
        centre("AXStaticText", "A message that must never be read"),
    ]
    if recents {
        nodes += [
            side("AXButton", "Recents"), side("AXButton", "New chat"),
            side("AXStaticText", "Unread"), side("AXButton", "Chat X", onPress: press), side("AXStaticText", "Chat X"), side("AXButton", "Pin chat"),
            side("AXButton", "Chat Y", onPress: press), side("AXStaticText", "Chat Y"), side("AXButton", "Pin chat"),
            side("AXButton", "Chat Y", onPress: press), side("AXStaticText", "Chat Y"),
        ]
    }
    return fakeWindow(nodes)
}

@Suite("Reading the Claude and ChatGPT apps' sidebars")
struct DesktopAdapterTests {
    @Test("Claude: chats only, never project names, controls, labels or message text; equal titles are kept")
    func claudeReads() {
        let reading = ClaudeDesktopAdapter().read(claudeWindow())
        #expect(reading == .entries([SidebarEntry(title: "Chat A"), SidebarEntry(title: "Chat B"), SidebarEntry(title: "Chat A"), SidebarEntry(title: "Untitled")]))
    }

    @Test("Claude: with the sidebar closed the layout is unrecognised, not an empty list")
    func claudeClosed() {
        guard case .unrecognised(let reason) = ClaudeDesktopAdapter().read(claudeWindow(sidebarOpen: false)) else { Issue.record("expected unrecognised"); return }
        #expect(reason.contains("sidebar"))
    }

    @Test("Claude: the nth equal title is the control for ordinal n, and pressing it presses its row")
    func claudeControl() throws {
        let adapter = ClaudeDesktopAdapter()
        let window = claudeWindow()
        let second = try #require(adapter.control(for: SidebarEntry(title: "Chat A"), ordinal: 1, in: window))
        #expect(second.label == "Chat A" && second.role == "AXStaticText")
        #expect(adapter.control(for: SidebarEntry(title: "Chat A"), ordinal: 2, in: window) == nil)
        #expect(adapter.control(for: SidebarEntry(title: "Nope"), ordinal: 0, in: window) == nil)
    }

    @Test("ChatGPT: only the Recents list, in order, with Unread attached to the next chat only")
    func chatgptReads() {
        let reading = ChatGPTDesktopAdapter().read(chatgptWindow())
        #expect(reading == .entries([SidebarEntry(title: "Chat X", unread: true), SidebarEntry(title: "Chat Y"), SidebarEntry(title: "Chat Y")]))
    }

    @Test("ChatGPT: without a Recents header the layout is unrecognised")
    func chatgptUnrecognised() {
        guard case .unrecognised = ChatGPTDesktopAdapter().read(chatgptWindow(recents: false)) else { Issue.record("expected unrecognised"); return }
    }

    @Test("ChatGPT: the control for a chat is its own button, chosen by ordinal among equal titles")
    func chatgptControl() {
        let adapter = ChatGPTDesktopAdapter()
        let window = chatgptWindow()
        #expect(adapter.control(for: SidebarEntry(title: "Chat Y"), ordinal: 1, in: window) != nil)
        #expect(adapter.control(for: SidebarEntry(title: "Chat Y"), ordinal: 2, in: window) == nil)
    }

    @Test("nothing outside the sidebar strip is ever visited as a candidate")
    func stripBound() {
        let window = claudeWindow()
        let labels = SidebarStrip.nodes(in: window, width: 300).map(\.label)
        #expect(!labels.contains("A message that must never be read"))
        #expect(labels.contains("Chat B"))
    }
}
