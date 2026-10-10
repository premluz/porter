import ConversationCore
import Foundation
import Synchronization
import Testing
@testable import NativeSources

private let now = Date(timeIntervalSince1970: 1_791_558_000)

private func session(
    _ id: String, tty: String = "ttys003", host: String = "com.apple.Terminal", cwd: String = "/Users/example/Atlas",
    ago: TimeInterval = 10, attention: Attention = .none
) -> TerminalSession {
    TerminalSession(sessionId: id, cwd: cwd, tty: tty, hostApp: host, activity: .working, attention: attention, receivedAt: now.addingTimeInterval(-ago))
}

private func request(_ id: String, title: String = "x") throws -> ActivateRequestPayload {
    let json = #"{"requestId":"\#(UUID())","destinationId":"\#(UUID())","destinationRevision":1,"expectedProvider":"claude-code","expectedConversationId":"\#(id)","app":{"bundleId":"com.apple.Terminal","expectedTitle":"\#(title)","ordinal":0}}"#
    return try ContractCoding.decoder().decode(ActivateRequestPayload.self, from: Data(json.utf8))
}

private func titleRecord(_ tty: String, _ title: String) -> String { "/dev/\(tty)\u{1F}\(title)\u{1E}" }

@Suite("Agents in terminals as routes")
struct TerminalSessionsTests {
    private func connector(_ sessions: [TerminalSession], runner: FakeRunner = FakeRunner(), running: Bool = true) -> TerminalSessionsConnector {
        TerminalSessionsConnector(
            installationId: UUID(), sessions: { sessions }, runner: runner, pollInterval: .milliseconds(20), isRunning: { _ in running }
        )
    }

    @Test("each session becomes an entry keyed by its id, with its project, host, real last-activity time and the list order")
    func snapshot() async throws {
        let entries = try #require(try await connector([session("s-new", ago: 5), session("s-old", tty: "ttys004", ago: 500)]).snapshot().appEntries)
        #expect(entries.map(\.providerConversationId) == ["s-new", "s-old"] && entries.map(\.position) == [0, 1])
        #expect(entries.allSatisfy { $0.provider == "claude-code" && $0.bundleId == "com.apple.Terminal" && $0.workspacePath == "/Users/example/Atlas" })
        #expect(entries[0].lastActiveAt == now.addingTimeInterval(-5))
    }

    @Test("a terminal's tab title names the entry; without one it is called after the folder")
    func titles() async throws {
        let runner = FakeRunner()
        runner.setList(titleRecord("ttys003", "✳ Fix the login redirect") + titleRecord("ttys009", "bash"))
        let entries = try #require(try await connector([session("a"), session("b", tty: "ttys004")], runner: runner).snapshot().appEntries)
        #expect(entries.map(\.title) == ["Fix the login redirect", "Claude Code in Atlas"])
        let quiet = try #require(try await connector([session("a")], running: false).snapshot().appEntries)
        #expect(quiet.first?.title == "Claude Code in Atlas")
    }

    @Test("a session is brought forward by its terminal device in Terminal, and the script is only given that device")
    func focusesTerminal() async throws {
        let runner = FakeRunner()
        let source = connector([session("a", tty: "ttys003")], runner: runner)
        #expect(await source.activate(try request("a")) == .activated)
        #expect(runner.scripts.last?.arguments == ["ttys003"] && runner.scripts.last?.script.contains("com.apple.Terminal") == true)
        runner.setActivate("gone")
        #expect(await source.activate(try request("a")) == .targetGone)
        #expect(await source.activate(try request("not-listed")) == .targetGone)
    }

    @Test("a terminal that cannot be driven by tab is not claimed, one in VS Code only needs its window, and a closed one is offline")
    func otherHosts() async throws {
        let ghostty = connector([session("g", host: "com.mitchellh.ghostty")])
        #expect(await ghostty.activate(try request("g")) == .unsupported)
        let code = connector([session("v", host: "com.microsoft.VSCode")])
        #expect(await code.activate(try request("v")) == .activated)
        let closed = connector([session("a")], running: false)
        #expect(await closed.activate(try request("a")) == .connectorOffline)
    }

    @Test("a refused Automation permission is reported as such")
    func permission() async throws {
        let runner = FakeRunner()
        runner.setError(.permissionDenied)
        #expect(await connector([session("a")], runner: runner).activate(try request("a")) == .permissionDenied)
    }

    @Test("titles parse from either terminal's list, normalising the device and ignoring empty titles")
    func parsing() {
        let parsed = TerminalScripts.parseTitles(titleRecord("ttys001", "One") + "ttys002\u{1F}\u{1E}" + "garbage\u{1E}")
        #expect(parsed == ["ttys001": "One"])
        #expect(TerminalScripts.titles(for: "com.googlecode.iterm2")?.contains("sessions of t") == true)
        #expect(TerminalScripts.titles(for: "com.mitchellh.ghostty") == nil && TerminalScripts.focus(bundleId: "org.example.Term") == nil)
    }

    @Test("a new or changed session is noticed by the poll")
    func noticesChanges() async throws {
        let live = Mutex<[TerminalSession]>([session("a")])
        let source = TerminalSessionsConnector(
            installationId: UUID(), sessions: { live.withLock { $0 } }, runner: FakeRunner(), pollInterval: .milliseconds(20), isRunning: { _ in true }
        )
        _ = try await source.snapshot()
        var iterator = source.changes().makeAsyncIterator()
        try await Task.sleep(for: .milliseconds(60))
        live.withLock { $0.append(session("b", tty: "ttys004")) }
        let changed: Void? = await iterator.next()
        #expect(changed != nil)
    }
}
