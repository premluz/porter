import ConversationCore
import Foundation
import Synchronization
import Testing
@testable import NativeSources

final class FakeRunner: ScriptRunning {
    private struct State {
        var listOutput = ""
        var activateOutput = "ok"
        var error: ScriptError?
        var scripts: [(script: String, arguments: [String])] = []
    }
    private let state = Mutex(State())

    var scripts: [(script: String, arguments: [String])] { state.withLock { $0.scripts } }
    func setList(_ output: String) { state.withLock { $0.listOutput = output } }
    func setError(_ error: ScriptError?) { state.withLock { $0.error = error } }
    func setActivate(_ output: String) { state.withLock { $0.activateOutput = output } }

    func run(_ script: String, arguments: [String]) async throws -> String {
        try state.withLock { state in
            state.scripts.append((script, arguments))
            if let error = state.error { throw error }
            return script.contains("on run argv") ? state.activateOutput : state.listOutput
        }
    }
}

/// One record as the list script prints it.
func record(window: Int = 1, windowId: Int = 900, active: Int = 1, position: Int = 1, tab: Int, url: String, title: String) -> String {
    [window, windowId, active, position, tab].map(String.init).joined(separator: "\u{1F}") + "\u{1F}\(url)\u{1F}\(title)\u{1E}"
}

func request(tab: Int?, window: Int?, chat: String, provider: String = "claude") throws -> ActivateRequestPayload {
    let ids = [tab.map { #""tabId":\#($0),"# }, window.map { #""windowId":\#($0),"# }].compactMap { $0 }.joined()
    let json = #"{"requestId":"\#(UUID())","destinationId":"\#(UUID())","destinationRevision":1,\#(ids)"expectedProvider":"\#(provider)","expectedConversationId":"\#(chat)"}"#
    return try ContractCoding.decoder().decode(ActivateRequestPayload.self, from: Data(json.utf8))
}

@Suite("Reading and driving Chrome by scripting")
struct ChromeScriptingTests {
    private let start = Date(timeIntervalSince1970: 1_791_450_000)

    private func connector(_ runner: FakeRunner, running: Bool = true) -> ChromeScriptingConnector {
        ChromeScriptingConnector(
            installationId: UUID(), runner: runner, pollInterval: .milliseconds(20), now: { start }, isRunning: { running }
        )
    }

    @Test("only conversations a recognizer accepts are reported, with clean titles and canonical URLs")
    func reportsConversations() async throws {
        let runner = FakeRunner()
        runner.setList(
            record(tab: 1, url: "https://claude.ai/chat/abc?x=1", title: "Plan - Claude")
                + record(position: 2, tab: 2, url: "https://claude.ai/new", title: "Claude")
                + record(position: 3, tab: 3, url: "https://chatgpt.com/c/zzz", title: "Trip - ChatGPT")
        )
        let payload = try await connector(runner).snapshot()
        #expect(payload.tabs.map(\.providerConversationId) == ["abc", "zzz"])
        #expect(payload.tabs.map(\.title) == ["Plan", "Trip"])
        #expect(payload.tabs.first?.canonicalUrl == "https://claude.ai/chat/abc")
        #expect(payload.tabs.map(\.provider) == ["claude", "chatgpt"])
    }

    @Test("unreadable records are skipped and counted, never guessed")
    func unreadable() {
        let parsed = ChromiumTabParser.parse(record(tab: 1, url: "https://claude.ai/chat/a", title: "A") + "garbage\u{1E}1\u{1F}x\u{1E}")
        #expect(parsed.tabs.count == 1 && parsed.unreadable == 2)
    }

    @Test("a browser that is not running is never asked, which would launch it")
    func notRunning() async throws {
        let runner = FakeRunner()
        let source = connector(runner, running: false)
        let payload = try await source.snapshot()
        #expect(payload.tabs.isEmpty && runner.scripts.isEmpty && source.health == .notRunning)
    }

    @Test("a refused permission is reported as such")
    func permissionRefused() async {
        let runner = FakeRunner()
        runner.setError(.permissionDenied)
        let source = connector(runner)
        await #expect(throws: ScriptError.permissionDenied) { try await source.snapshot() }
        #expect(source.health == .permissionDenied)
    }

    @Test("recency: only the tab in front of Chrome is stamped, when it arrives; others have no time")
    func recency() async throws {
        let runner = FakeRunner()
        runner.setList(
            record(window: 1, windowId: 1, active: 1, position: 1, tab: 10, url: "https://claude.ai/chat/front", title: "F")
                + record(window: 2, windowId: 2, active: 1, position: 1, tab: 20, url: "https://claude.ai/chat/back", title: "B")
                + record(window: 2, windowId: 2, active: 1, position: 2, tab: 21, url: "https://claude.ai/chat/hidden", title: "H")
        )
        let tabs = try await connector(runner).snapshot().tabs
        #expect(tabs.first { $0.tabId == 10 }?.lastActiveAt == start)
        #expect(tabs.first { $0.tabId == 20 }?.lastActiveAt == nil)
        #expect(tabs.first { $0.tabId == 21 }?.lastActiveAt == nil)
    }

    @Test("staying on a tab does not lift it again; moving to another tab or window stamps the one that arrives")
    func stampsArrivalsOnly() async throws {
        let clock = Mutex(start)
        let runner = FakeRunner()
        let source = ChromeScriptingConnector(
            installationId: UUID(), runner: runner, pollInterval: .milliseconds(20), now: { clock.withLock { $0 } }, isRunning: { true }
        )
        let one = record(window: 1, windowId: 1, active: 1, position: 1, tab: 10, url: "https://claude.ai/chat/a", title: "A")
        let two = record(window: 2, windowId: 2, active: 1, position: 1, tab: 20, url: "https://claude.ai/chat/b", title: "B")
        runner.setList(one + two)
        _ = try await source.snapshot()
        clock.withLock { $0 = start.addingTimeInterval(600) }
        let stayed = try await source.snapshot().tabs
        #expect(stayed.first { $0.tabId == 10 }?.lastActiveAt == start)
        // The person switches to the other window: it becomes the front one.
        runner.setList(
            record(window: 1, windowId: 2, active: 1, position: 1, tab: 20, url: "https://claude.ai/chat/b", title: "B")
                + record(window: 2, windowId: 1, active: 1, position: 1, tab: 10, url: "https://claude.ai/chat/a", title: "A")
        )
        let moved = try await source.snapshot().tabs
        #expect(moved.first { $0.tabId == 20 }?.lastActiveAt == start.addingTimeInterval(600))
        #expect(moved.first { $0.tabId == 10 }?.lastActiveAt == start)
    }

    @Test("the list script asks only for provider hosts and skips incognito windows; both scripts use window ids")
    func scriptShape() {
        let list = ChromiumScripts.list(browser: .chrome, hosts: ["claude.ai", "chatgpt.com"])
        #expect(list.contains("https://claude.ai/") && list.contains("https://chatgpt.com/"))
        #expect(list.contains("is not \"incognito\""))
        #expect(ChromiumScripts.activate(browser: .chrome).contains("window id wid"))
        #expect(!list.contains("name of"))
    }
}

@Suite("Activating a Chrome tab re-checks the target first")
struct ChromeActivationTests {
    private func connector(_ runner: FakeRunner) -> ChromeScriptingConnector {
        ChromeScriptingConnector(installationId: UUID(), runner: runner, now: { Date() }, isRunning: { true })
    }

    @Test("a tab that is still the expected conversation is brought forward by window and tab id")
    func activates() async throws {
        let runner = FakeRunner()
        runner.setList(record(windowId: 900, tab: 77, url: "https://claude.ai/chat/abc", title: "A"))
        let outcome = await connector(runner).activate(try request(tab: 77, window: 900, chat: "abc"))
        #expect(outcome == .activated)
        #expect(runner.scripts.last?.arguments == ["900", "77"])
    }

    @Test("a closed tab is gone, and a tab that now shows another chat has changed; neither is activated")
    func refusesStaleTargets() async throws {
        let runner = FakeRunner()
        runner.setList(record(windowId: 900, tab: 77, url: "https://claude.ai/chat/other", title: "O"))
        let source = connector(runner)
        #expect(await source.activate(try request(tab: 77, window: 900, chat: "abc")) == .targetChanged)
        #expect(await source.activate(try request(tab: 78, window: 900, chat: "abc")) == .targetGone)
        #expect(runner.scripts.allSatisfy { !$0.script.contains("on run argv") })
    }

    @Test("a provider mismatch counts as changed, an editor request is unsupported, and a refused permission is reported")
    func otherOutcomes() async throws {
        let runner = FakeRunner()
        runner.setList(record(windowId: 900, tab: 77, url: "https://claude.ai/chat/abc", title: "A"))
        let source = connector(runner)
        #expect(await source.activate(try request(tab: 77, window: 900, chat: "abc", provider: "chatgpt")) == .targetChanged)
        #expect(await source.activate(try request(tab: nil, window: nil, chat: "abc")) == .unsupported)
        runner.setError(.permissionDenied)
        #expect(await source.activate(try request(tab: 77, window: 900, chat: "abc")) == .permissionDenied)
    }

    @Test("a script that reports the tab missing at the last moment is gone")
    func vanishesAtTheLastMoment() async throws {
        let runner = FakeRunner()
        runner.setList(record(windowId: 900, tab: 77, url: "https://claude.ai/chat/abc", title: "A"))
        runner.setActivate("gone")
        #expect(await connector(runner).activate(try request(tab: 77, window: 900, chat: "abc")) == .targetGone)
    }
}
