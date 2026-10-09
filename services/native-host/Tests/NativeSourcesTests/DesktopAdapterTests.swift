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
        #expect(reading == .entries([
            SidebarEntry(title: "Chat A", section: "Yesterday"), SidebarEntry(title: "Chat B", section: "Older"),
            SidebarEntry(title: "Chat A", section: "Older"), SidebarEntry(title: "Untitled", section: "Older"),
        ]))
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

@Suite("Turning an app's group heading into a day")
struct AppSectionDateTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    /// Friday 2026-10-09, 15:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_791_558_000)

    private func day(_ date: Date?) -> String? {
        date.map { calendar.dateComponents([.month, .day, .hour], from: $0) }.map { "\($0.month ?? 0)/\($0.day ?? 0) \($0.hour ?? 0)h" }
    }

    @Test("Today is now, Yesterday and a dated heading are noon of that day, and a heading in the future means last year")
    func headings() {
        #expect(AppSectionDate.date(for: "Today", now: now, calendar: calendar) == now)
        #expect(day(AppSectionDate.date(for: "Yesterday", now: now, calendar: calendar)) == "10/8 12h")
        #expect(day(AppSectionDate.date(for: "Oct 7", now: now, calendar: calendar)) == "10/7 12h")
        #expect(day(AppSectionDate.date(for: "Dec 30", now: now, calendar: calendar)) == "12/30 12h")
        #expect(AppSectionDate.date(for: "Dec 30", now: now, calendar: calendar).map { calendar.component(.year, from: $0) } == 2025)
    }

    @Test("Older and anything not understood give no date, never a guessed one")
    func unknown() {
        for heading in [nil, "Older", "Last week", "Oct", "Foo 7", "Oct 40", ""] {
            #expect(AppSectionDate.date(for: heading, now: now, calendar: calendar) == nil, "\(heading ?? "nil")")
        }
    }
}
