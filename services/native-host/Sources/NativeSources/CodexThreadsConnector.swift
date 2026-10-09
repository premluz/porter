import AppKit
import ConversationCore
import Foundation

/// Opens a link with the system. A protocol so the connector can be tested without opening anything.
public protocol URLOpening: Sendable {
    func open(_ url: URL) async -> Bool
}

public struct WorkspaceURLOpener: URLOpening {
    public init() {}

    public func open(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
    }
}

/// Codex threads, from Codex's own thread list. VS Code's side panel hides its chats from every extension, but the
/// extension and the Codex desktop app write the same list, so Porter reads that instead: each recent thread is a
/// route under its project, opened through the link its owner documents in its code.
public final class CodexThreadsConnector: HostConnector {
    public static let provider = "codex"
    static let adapterVersion = "0.1.0"
    /// How far back threads are listed.
    static let window: TimeInterval = 7 * 86_400

    public let kind = ConnectorKind.desktopApp
    public let installationId: UUID
    public let profileAlias: String? = nil
    public var adapterVersions: [String: String] { [Self.provider: Self.adapterVersion] }

    private let index: CodexThreadIndex
    private let opener: any URLOpening
    private let now: @Sendable () -> Date
    private let pollInterval: Duration

    public init(
        installationId: UUID, index: CodexThreadIndex = CodexThreadIndex(), opener: any URLOpening = WorkspaceURLOpener(),
        pollInterval: Duration = .seconds(5), now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.installationId = installationId
        self.index = index
        self.opener = opener
        self.pollInterval = pollInterval
        self.now = now
    }

    public var isAvailable: Bool { index.isAvailable }

    public func snapshot() async throws -> InventorySnapshotPayload {
        let threads = index.recentThreads(now: now(), window: Self.window)
        let entries = threads.enumerated().map { position, thread in
            AppEntryReport(
                provider: Self.provider, providerConversationId: thread.id, title: thread.title,
                bundleId: Self.bundleId(for: thread), ordinal: 0, lastActiveAt: thread.updatedAt, position: position,
                workspacePath: thread.workspacePath.flatMap { $0.hasPrefix("/") ? $0 : nil }
            )
        }
        return InventorySnapshotPayload(tabs: [], appEntries: entries)
    }

    public func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let poller = Task { [self] in
                var seen = index.fingerprint()
                while !Task.isCancelled {
                    try? await Task.sleep(for: pollInterval)
                    let current = index.fingerprint()
                    if current != seen {
                        seen = current
                        continuation.yield()
                    }
                }
            }
            continuation.onTermination = { _ in poller.cancel() }
        }
    }

    public func activate(_ request: ActivateRequestPayload) async -> ActivationOutcome {
        guard request.app != nil, request.expectedProvider == Self.provider else { return .unsupported }
        let threads = index.recentThreads(now: now(), window: Self.window)
        guard let thread = threads.first(where: { $0.id == request.expectedConversationId }) else { return .targetGone }
        guard thread.title == request.app?.expectedTitle else { return .targetChanged }
        guard let link = Self.link(for: thread) else { return .failed }
        return await opener.open(link) ? .activated : .failed
    }

    /// A thread made in the VS Code extension is opened there; one made in the Codex app is opened in the app.
    static func bundleId(for thread: CodexThread) -> String {
        thread.startedInVSCode ? LocatorPolicy.vscodeBundleId : "com.openai.codex"
    }

    /// The extension's own link handler navigates to `/local/<id>`, and the app takes the same route under its scheme.
    static func link(for thread: CodexThread) -> URL? {
        guard thread.id.wholeMatch(of: /[A-Za-z0-9-]{8,64}/) != nil else { return nil }
        return thread.startedInVSCode ? URL(string: "vscode://openai.chatgpt/local/\(thread.id)") : URL(string: "codex://local/\(thread.id)")
    }
}
