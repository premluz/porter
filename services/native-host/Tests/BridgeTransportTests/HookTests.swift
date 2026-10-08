import ConversationCore
import Darwin
import Foundation
import Testing
@testable import BridgeTransport

@Suite("Claude Code hook input and the porterctl hook command", .serialized)
struct HookTests {
    private static let secretPrompt = "SECRET-PROMPT-TEXT please do not store this"
    private static let secretTool = "SECRET-TOOL-ARGUMENT /etc/passwd"

    private func hookJSON(event: String = "UserPromptSubmit", session: String = "sess-1", extra: String = "") -> Data {
        Data("""
        {"session_id":"\(session)","transcript_path":"/Users/x/.claude/projects/p/sess-1.jsonl","cwd":"/Users/example/Porter",\
        "hook_event_name":"\(event)","prompt":"\(Self.secretPrompt)","tool_input":{"command":"\(Self.secretTool)"}\(extra)}
        """.utf8)
    }

    @Test("only the whitelisted fields survive; the prompt, tool input and transcript path do not")
    func privacy() throws {
        let event = try HookInput.parse(hookJSON(extra: #","notification_type":"permission_prompt""#), entrypoint: "claude-vscode")
        #expect(event == AgentEvent(event: "UserPromptSubmit", sessionId: "sess-1", cwd: "/Users/example/Porter", notificationType: "permission_prompt", entrypoint: "claude-vscode"))
        let encoded = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
        for secret in [Self.secretPrompt, Self.secretTool, "transcript", ".jsonl", "tool_input"] {
            #expect(!encoded.contains(secret), "\(secret)")
        }
    }

    @Test("unreadable input is an error that names the missing field and never echoes the input")
    func errors() {
        #expect(throws: HookInputError.notAnObject) { try HookInput.parse(Data("[1,2]".utf8), entrypoint: nil) }
        #expect(throws: HookInputError.notAnObject) { try HookInput.parse(Data("not json \(Self.secretPrompt)".utf8), entrypoint: nil) }
        #expect(throws: HookInputError.missing("cwd")) { try HookInput.parse(Data(#"{"session_id":"s","hook_event_name":"Stop"}"#.utf8), entrypoint: nil) }
        #expect(throws: HookInputError.missing("session_id")) { try HookInput.parse(Data(#"{"cwd":"/p","hook_event_name":"Stop"}"#.utf8), entrypoint: nil) }
        #expect(throws: HookInputError.missing("hook_event_name")) { try HookInput.parse(Data(#"{"cwd":"/p","session_id":"s"}"#.utf8), entrypoint: nil) }
    }

    private struct Run {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    private func porterctl(_ arguments: [String], stdin: Data, support: String, entrypoint: String? = "claude-vscode") throws -> Run {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: ".build/debug/porterctl").standardizedFileURL
        process.arguments = arguments
        var environment = ["PORTER_SUPPORT_DIR": support]
        if let entrypoint { environment["CLAUDE_CODE_ENTRYPOINT"] = entrypoint }
        process.environment = environment
        let input = Pipe(), output = Pipe(), errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        input.fileHandleForWriting.write(stdin)
        input.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        return Run(
            status: process.terminationStatus,
            stdout: String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    private func emptySupport() -> String {
        let directory = NSTemporaryDirectory() + "porter-hook-\(UInt32.random(in: 0...UInt32.max))"
        mkdir(directory, 0o700)
        return directory
    }

    @Test("with Porter not running the hook still prints nothing and exits 0, leaving a note only on stderr")
    func registryDown() throws {
        let run = try porterctl(["hook"], stdin: hookJSON(), support: emptySupport())
        #expect(run.status == 0 && run.stdout.isEmpty)
        #expect(run.stderr.contains("porter hook"))
        #expect(!run.stderr.contains(Self.secretPrompt) && !run.stderr.contains(Self.secretTool))
    }

    @Test("garbage and oversized input are survived the same way")
    func garbageAndOversized() throws {
        let support = emptySupport()
        let garbage = try porterctl(["hook"], stdin: Data("}{ not json \(Self.secretPrompt)".utf8), support: support)
        #expect(garbage.status == 0 && garbage.stdout.isEmpty && !garbage.stderr.contains(Self.secretPrompt))
        let huge = try porterctl(["hook"], stdin: Data(repeating: 0x20, count: HookInput.maximumBytes + 10), support: support)
        #expect(huge.status == 0 && huge.stdout.isEmpty)
    }

    @Test("a hook event reaches the registry and puts Working on the one tab in that window")
    func endToEnd() throws {
        let directory = NSTemporaryDirectory() + "porter-hook-e2e-\(UInt32.random(in: 0...UInt32.max))"
        #expect(mkdir(directory, 0o700) == 0)
        let service = RegistryService(deviceId: UUID(), log: { _ in }, focusApplication: { "" })
        try service.start(bridgePath: directory + "/bridge.sock", controlPath: directory + "/control.sock")
        let editor = try FakeEditor(socketPath: directory + "/bridge.sock")
        defer { editor.close() }
        try editor.hello(folder: "Porter")
        _ = editor.receive()
        try editor.snapshot(path: "/Users/example/Porter", title: "Release plan")
        for _ in 0..<100 where service.listing().rows.isEmpty { Thread.sleep(forTimeInterval: 0.02) }
        let route = try #require(service.listing().rows.first)
        #expect(service.statuses().isEmpty)

        let run = try porterctl(["hook"], stdin: hookJSON(), support: directory)
        #expect(run.status == 0 && run.stdout.isEmpty && run.stderr.isEmpty)
        #expect(service.statuses()[route.destinationId]?.display == .working)

        let terminal = try porterctl(["hook"], stdin: hookJSON(event: "Stop", session: "terminal-session"), support: directory, entrypoint: "cli")
        #expect(terminal.status == 0)
        #expect(service.statuses()[route.destinationId]?.display == .working)
        let stop = try porterctl(["hook"], stdin: hookJSON(event: "Stop"), support: directory)
        #expect(stop.status == 0)
        #expect(service.statuses()[route.destinationId]?.display == .idle)
    }

    @Test("the control socket refuses an event it does not understand, with a reason, and keeps working")
    func refusedEvent() throws {
        let directory = NSTemporaryDirectory() + "porter-hook-bad-\(UInt32.random(in: 0...UInt32.max))"
        #expect(mkdir(directory, 0o700) == 0)
        let service = RegistryService(deviceId: UUID(), log: { _ in }, focusApplication: { "" })
        try service.start(bridgePath: directory + "/bridge.sock", controlPath: directory + "/control.sock")
        let bad = AgentEvent(event: "Whatever", sessionId: "s", cwd: "/p", entrypoint: "claude-vscode")
        let connection = FramedConnection(fd: try UnixSocket.connect(path: directory + "/control.sock"))
        defer { connection.closeDescriptor() }
        try connection.send(try JSONEncoder().encode(ControlRequest(command: .agentEvent, agent: bad)))
        let reply = try #require(try connection.receive(maximumBytes: ControlLimits.maximumResponseBytes))
        let response = try JSONDecoder().decode(ControlResponse.self, from: reply)
        #expect(!response.ok && response.error?.contains("unsupportedEvent") == true)
    }

    @Test("hook-config prints valid JSON naming every event, running in the background, with this program's path")
    func configuration() throws {
        let run = try porterctl(["hook-config"], stdin: Data(), support: emptySupport())
        let object = try #require(JSONSerialization.jsonObject(with: Data(run.stdout.utf8)) as? [String: Any])
        let hooks = try #require(object["hooks"] as? [String: Any])
        #expect(Set(hooks.keys) == ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Notification", "Stop", "SessionEnd"])
        let group = try #require((hooks["Stop"] as? [[String: Any]])?.first)
        let command = try #require((group["hooks"] as? [[String: Any]])?.first)
        #expect(command["type"] as? String == "command" && command["async"] as? Bool == true)
        #expect((command["command"] as? String)?.hasSuffix("porterctl hook") == true)
    }
}
