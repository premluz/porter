import BridgeTransport
import ConversationCore
import Darwin
import Foundation

/// The command Claude Code runs on its hook events. It must never get in Claude's way: it prints nothing
/// (anything a prompt hook prints becomes part of the conversation), always exits 0 (a non-zero code is
/// reported as a failure), and gives up quickly if Porter is not running. Problems go to stderr, which
/// Claude Code keeps in its debug log only.
enum Hook {
    private static let entrypointVariable = "CLAUDE_CODE_ENTRYPOINT"
    private static let replyTimeoutSeconds = 2
    /// Events Porter listens to, in the order they usually occur.
    private static let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Notification", "Stop", "SessionEnd"]
    private static let hookTimeoutSeconds = 5

    static func run() -> Never {
        do {
            let input = FileHandle.standardInput.readData(ofLength: HookInput.maximumBytes + 1)
            guard input.count <= HookInput.maximumBytes else { throw HookFailure("hook input is larger than \(HookInput.maximumBytes) bytes") }
            let entrypoint = ProcessInfo.processInfo.environment[entrypointVariable]
            try send(withPlacement(try HookInput.parse(input, entrypoint: entrypoint)))
        } catch {
            FileHandle.standardError.write(Data("porter hook: \(error)\n".utf8))
        }
        exit(0)
    }

    /// An agent started from VS Code's panel has a tab; any other (a terminal) is placed by the terminal it runs in.
    private static func withPlacement(_ event: AgentEvent) -> AgentEvent {
        guard event.entrypoint != AgentEvent.vscodeEntrypoint else { return event }
        let placement = TerminalProbe.probe(from: getppid(), table: LiveProcessTable(), bundleId: TerminalProbe.bundleIdentifier(ofApplicationAt:))
        return AgentEvent(
            event: event.event, sessionId: event.sessionId, cwd: event.cwd, notificationType: event.notificationType,
            entrypoint: event.entrypoint, tty: placement.tty, hostApp: placement.hostApp
        )
    }

    private struct HookFailure: Error, CustomStringConvertible {
        let description: String
        init(_ description: String) { self.description = description }
    }

    private static func send(_ event: AgentEvent) throws {
        let connection = FramedConnection(fd: try UnixSocket.connect(path: PorterPaths.controlSocket()))
        defer { connection.closeDescriptor() }
        var timeout = timeval(tv_sec: replyTimeoutSeconds, tv_usec: 0)
        setsockopt(connection.fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        try connection.send(try JSONEncoder().encode(ControlRequest(command: .agentEvent, agent: event)))
        guard let reply = try connection.receive(maximumBytes: ControlLimits.maximumResponseBytes) else {
            throw HookFailure("Porter closed the connection without a reply")
        }
        let response = try JSONDecoder().decode(ControlResponse.self, from: reply)
        if !response.ok { throw HookFailure(response.error ?? "Porter refused the event") }
    }

    /// The `hooks` section to merge into a Claude Code settings file. Hooks run in the background so
    /// Claude never waits for Porter.
    static func configuration(executable: String) -> String {
        let command: [String: Any] = ["type": "command", "command": "\(executable) hook", "async": true, "timeout": hookTimeoutSeconds]
        var hooks: [String: Any] = [:]
        for event in events { hooks[event] = [["hooks": [command]]] }
        let document: [String: Any] = ["hooks": hooks]
        guard let data = try? JSONSerialization.data(withJSONObject: document, options: [.prettyPrinted, .sortedKeys]) else {
            return "{}"
        }
        return String(decoding: data, as: UTF8.self)
    }
}
