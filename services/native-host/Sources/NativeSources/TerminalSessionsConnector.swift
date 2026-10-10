import AppKit
import ConversationCore
import Foundation
import Synchronization

/// Coding agents running in terminals, from the status events their hooks send. The hook knows the terminal device and
/// the hosting application (it runs beside the agent), so each session is a route of its own: listed with its project,
/// real last-activity time and status, and brought forward by finding its tab where the terminal allows it.
public final class TerminalSessionsConnector: HostConnector {
    public static let provider = AgentEvent.claudeCodeSource
    static let adapterVersion = "0.1.0"

    public let kind = ConnectorKind.desktopApp
    public let installationId: UUID
    public let profileAlias: String? = nil
    public var adapterVersions: [String: String] { [Self.provider: Self.adapterVersion] }

    private let sessions: @Sendable () -> [TerminalSession]
    private let runner: any ScriptRunning
    private let isRunning: @Sendable (String) -> Bool
    private let pollInterval: Duration
    private let lastFingerprint = Mutex<[String]>([])

    public init(
        installationId: UUID, sessions: @escaping @Sendable () -> [TerminalSession], runner: any ScriptRunning = OsascriptRunner(),
        pollInterval: Duration = .seconds(2),
        isRunning: @escaping @Sendable (String) -> Bool = { !NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }
    ) {
        self.installationId = installationId
        self.sessions = sessions
        self.runner = runner
        self.pollInterval = pollInterval
        self.isRunning = isRunning
    }

    public func snapshot() async throws -> InventorySnapshotPayload {
        let live = sessions()
        let titles = await tabTitles(for: live)
        let entries = live.enumerated().map { position, session in
            AppEntryReport(
                provider: Self.provider, providerConversationId: session.sessionId,
                title: Self.title(for: session, tabTitle: titles[session.hostApp]?[session.tty]), bundleId: session.hostApp,
                ordinal: 0, lastActiveAt: session.receivedAt, position: position, workspacePath: session.cwd
            )
        }
        lastFingerprint.withLock { $0 = Self.fingerprint(live) }
        return InventorySnapshotPayload(tabs: [], appEntries: entries)
    }

    public func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let poller = Task { [self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: pollInterval)
                    let current = Self.fingerprint(sessions())
                    let changed = lastFingerprint.withLock { known in
                        defer { known = current }
                        return known != current
                    }
                    if changed { continuation.yield() }
                }
            }
            continuation.onTermination = { _ in poller.cancel() }
        }
    }

    public func activate(_ request: ActivateRequestPayload) async -> ActivationOutcome {
        guard request.app != nil, request.expectedProvider == Self.provider else { return .unsupported }
        guard let session = sessions().first(where: { $0.sessionId == request.expectedConversationId }) else { return .targetGone }
        if session.hostApp == LocatorPolicy.vscodeBundleId { return .activated }
        guard let script = TerminalScripts.focus(bundleId: session.hostApp) else { return .unsupported }
        guard isRunning(session.hostApp) else { return .connectorOffline }
        do {
            let result = try await runner.run(script, arguments: [session.tty])
            return result == "ok" ? .activated : .targetGone
        } catch ScriptError.permissionDenied {
            return .permissionDenied
        } catch ScriptError.timedOut {
            return .timeout
        } catch {
            return .failed
        }
    }

    /// The tab titles of each running terminal that can say them, by device. A terminal that cannot, or is not running,
    /// is left out and its sessions get a plain name.
    private func tabTitles(for live: [TerminalSession]) async -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        for host in Set(live.map(\.hostApp)) {
            guard let script = TerminalScripts.titles(for: host), isRunning(host) else { continue }
            if let output = try? await runner.run(script, arguments: []) { result[host] = TerminalScripts.parseTitles(output) }
        }
        return result
    }

    static func title(for session: TerminalSession, tabTitle: String?) -> String {
        let folder = (session.cwd as NSString).lastPathComponent
        let cleaned = tabTitle?.trimmingCharacters(in: CharacterSet(charactersIn: "✳✻·*⠂⠐ \t"))
        if let cleaned, !cleaned.isEmpty { return String(cleaned.prefix(BridgeLimits.maximumTitleLength)) }
        return "Claude Code in \(folder.isEmpty ? "a terminal" : folder)"
    }

    private static func fingerprint(_ sessions: [TerminalSession]) -> [String] {
        sessions.map { "\($0.sessionId)|\($0.tty)|\($0.hostApp)|\($0.receivedAt.timeIntervalSince1970)" }
    }
}
