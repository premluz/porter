import AppKit
import ConversationCore
import Foundation
import Synchronization

/// What the setup screen and diagnostics can say about a source without guessing.
public enum SourceHealth: Sendable, Equatable {
    case unknown, ready, notRunning, permissionDenied
    case failed(String)
}

/// Porter reading a Chromium browser itself, with no extension: it asks the browser for its tabs on the
/// provider hosts, and brings one forward by window and tab id. It cannot tell which profile a window is in,
/// so it reports none; the registry then shows the profile as unknown.
public final class ChromeScriptingConnector: HostConnector {
    public let kind = ConnectorKind.chromeScripting
    public let installationId: UUID
    public let profileAlias: String? = nil
    public var adapterVersions: [String: String] { ProviderRecognizers.adapterVersions }

    private struct State {
        var health = SourceHealth.unknown
        /// The last time each tab was seen as its window's visible one, for ordering only.
        var lastVisible: [Int: Date] = [:]
        var fingerprint: [String] = []
    }

    private let browser: ChromiumBrowser
    private let runner: any ScriptRunning
    private let isRunning: @Sendable () -> Bool
    private let now: @Sendable () -> Date
    private let pollInterval: Duration
    private let state = Mutex(State())

    public init(
        installationId: UUID, browser: ChromiumBrowser = .chrome, runner: any ScriptRunning = OsascriptRunner(),
        pollInterval: Duration = .seconds(2), now: @escaping @Sendable () -> Date = { Date() },
        isRunning: (@Sendable () -> Bool)? = nil
    ) {
        self.installationId = installationId
        self.browser = browser
        self.runner = runner
        self.pollInterval = pollInterval
        self.now = now
        let bundleId = browser.bundleId
        // Asking a scripted application to do anything launches it, so whether it runs is checked first.
        self.isRunning = isRunning ?? { !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty }
    }

    public var health: SourceHealth { state.withLock { $0.health } }

    public func snapshot() async throws -> InventorySnapshotPayload {
        try await fetch().payload
    }

    public func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let poller = Task { [self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: pollInterval)
                    guard let fetched = try? await fetch() else { continue }
                    let changed = state.withLock { state in
                        defer { state.fingerprint = fetched.fingerprint }
                        return state.fingerprint != fetched.fingerprint
                    }
                    if changed { continuation.yield() }
                }
            }
            continuation.onTermination = { _ in poller.cancel() }
        }
    }

    public func activate(_ request: ActivateRequestPayload) async -> ActivationOutcome {
        guard let tabId = request.tabId, let windowId = request.windowId else { return .unsupported }
        do {
            let tabs = try await listTabs()
            guard let tab = tabs.first(where: { $0.tabId == tabId && $0.windowId == windowId }) else { return .targetGone }
            guard let (recognizer, match) = ProviderRecognizers.recognize(url: tab.url),
                  recognizer.provider == request.expectedProvider,
                  match.providerConversationId == request.expectedConversationId else { return .targetChanged }
            let result = try await runner.run(ChromiumScripts.activate(browser: browser), arguments: [String(windowId), String(tabId)])
            return result == "ok" ? .activated : .targetGone
        } catch ScriptError.permissionDenied {
            record(.permissionDenied)
            return .permissionDenied
        } catch ScriptError.timedOut {
            return .timeout
        } catch {
            record(.failed("\(error)"))
            return .failed
        }
    }

    private func record(_ health: SourceHealth) { state.withLock { $0.health = health } }

    private func listTabs() async throws -> [ScriptedTab] {
        guard isRunning() else { return [] }
        let hosts = ProviderRecognizers.all.flatMap(\.hosts)
        let output = try await runner.run(ChromiumScripts.list(browser: browser, hosts: hosts), arguments: [])
        return ChromiumTabParser.parse(output).tabs
    }

    private func fetch() async throws -> (payload: InventorySnapshotPayload, fingerprint: [String]) {
        guard isRunning() else {
            state.withLock { $0.health = .notRunning; $0.lastVisible = [:] }
            return (InventorySnapshotPayload(tabs: []), [])
        }
        let tabs: [ScriptedTab]
        do {
            tabs = try await listTabs()
        } catch ScriptError.permissionDenied {
            record(.permissionDenied)
            throw ScriptError.permissionDenied
        } catch {
            record(.failed("\(error)"))
            throw error
        }
        let moment = now()
        let recognized = state.withLock { state -> [(tab: ScriptedTab, report: TabReport)] in
            state.health = .ready
            let recognized = ChromiumTabParser.reports(tabs) { tab in
                if tab.isActive { state.lastVisible[tab.tabId] = tab.isInFrontWindow ? moment : (state.lastVisible[tab.tabId] ?? moment) }
                return state.lastVisible[tab.tabId]
            }
            let present = Set(recognized.map(\.report.tabId))
            state.lastVisible = state.lastVisible.filter { present.contains($0.key) }
            return recognized
        }
        let reports = recognized.map(\.report)
        let fingerprint = recognized.map { pair in
            "\(pair.report.tabId)|\(pair.report.windowId)|\(pair.report.providerConversationId)|\(pair.report.title)|\(pair.tab.isActive)"
        }
        return (InventorySnapshotPayload(tabs: reports), fingerprint)
    }
}
