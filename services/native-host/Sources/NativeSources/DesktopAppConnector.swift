import ConversationCore
import CryptoKit
import Foundation
import Synchronization

/// Porter reading desktop chat apps (Claude, ChatGPT) through Accessibility: it lists each app's sidebar and presses
/// an entry to open it. An app that is not running is not asked; one whose window cannot be read keeps its last
/// list, since Porter re-checks the entry before pressing and says so if it is gone.
public final class DesktopAppConnector: HostConnector {
    public let kind = ConnectorKind.desktopApp
    public let installationId: UUID
    public let profileAlias: String? = nil
    public var adapterVersions: [String: String] { Dictionary(uniqueKeysWithValues: adapters.map { ($0.provider, $0.adapterVersion) }) }

    private struct State {
        var health: [String: SourceHealth] = [:]
        var lastEntries: [String: [AppEntryReport]] = [:]
        var fingerprint: [String] = []
    }

    private let adapters: [any DesktopAppAdapter]
    private let accessibility: any AccessibilityProviding
    private let pollInterval: Duration
    private let state = Mutex(State())

    public init(
        installationId: UUID, adapters: [any DesktopAppAdapter] = [ClaudeDesktopAdapter(), ChatGPTDesktopAdapter()],
        accessibility: any AccessibilityProviding = LiveAccessibility(), pollInterval: Duration = .seconds(3)
    ) {
        self.installationId = installationId
        self.adapters = adapters
        self.accessibility = accessibility
        self.pollInterval = pollInterval
    }

    /// Per app, keyed by the adapter's provider, for the setup screen and diagnostics.
    public var health: [String: SourceHealth] { state.withLock { $0.health } }

    public func snapshot() async throws -> InventorySnapshotPayload {
        InventorySnapshotPayload(tabs: [], appEntries: try await fetch().entries)
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
        guard let target = request.app, let adapter = adapters.first(where: { $0.bundleId == target.bundleId }) else { return .unsupported }
        do {
            let pressed: Bool? = try await accessibility.withWindow(bundleId: adapter.bundleId) { window in
                guard case .entries(let entries) = adapter.read(window) else { return nil }
                let sameTitle = entries.filter { $0.title == target.expectedTitle }
                guard let entry = sameTitle.first else { return nil }
                guard sameTitle.indices.contains(target.ordinal) else { return false }
                guard let control = adapter.control(for: entry, ordinal: target.ordinal, in: window) else { return nil }
                return control.press()
            }
            switch pressed {
            case nil: return .targetGone
            case false: return .targetChanged
            case true:
                accessibility.bringForward(bundleId: adapter.bundleId)
                return .activated
            }
        } catch AccessibilityError.notTrusted {
            record(adapter, .permissionDenied)
            return .permissionDenied
        } catch AccessibilityError.notRunning, AccessibilityError.noWindow {
            return .connectorOffline
        } catch {
            record(adapter, .failed("\(error)"))
            return .failed
        }
    }

    private func record(_ adapter: any DesktopAppAdapter, _ health: SourceHealth) {
        state.withLock { $0.health[adapter.provider] = health }
    }

    private func fetch() async throws -> (entries: [AppEntryReport], fingerprint: [String]) {
        var all: [AppEntryReport] = []
        for adapter in adapters {
            all += await entries(for: adapter)
        }
        return (all, all.map { "\($0.providerConversationId)|\($0.title)|\($0.unread ?? false)" })
    }

    private func entries(for adapter: any DesktopAppAdapter) async -> [AppEntryReport] {
        guard accessibility.isTrusted else {
            record(adapter, .permissionDenied)
            return []
        }
        guard accessibility.isRunning(bundleId: adapter.bundleId) else {
            state.withLock { $0.health[adapter.provider] = .notRunning; $0.lastEntries[adapter.provider] = nil }
            return []
        }
        do {
            let reading = try await accessibility.withWindow(bundleId: adapter.bundleId) { adapter.read($0) }
            switch reading {
            case .entries(let found):
                let reports = Self.reports(found, adapter: adapter)
                state.withLock { $0.health[adapter.provider] = .ready; $0.lastEntries[adapter.provider] = reports }
                return reports
            case .unrecognised(let reason):
                record(adapter, .failed(reason))
            }
        } catch AccessibilityError.noWindow {
            record(adapter, .failed("no readable window; bring \(adapter.displayName) to this desktop"))
        } catch {
            record(adapter, .failed("\(error)"))
        }
        return state.withLock { $0.lastEntries[adapter.provider] ?? [] }
    }

    /// Identity is the title plus its position among equal titles; the id is a short digest so it is a safe identifier.
    static func reports(_ entries: [SidebarEntry], adapter: any DesktopAppAdapter) -> [AppEntryReport] {
        var seen: [String: Int] = [:]
        return entries.prefix(BridgeLimits.maximumTabsPerSnapshot).enumerated().map { position, entry in
            let ordinal = seen[entry.title, default: 0]
            seen[entry.title] = ordinal + 1
            let digest = SHA256.hash(data: Data(entry.title.utf8)).prefix(6).map { String(format: "%02x", $0) }.joined()
            return AppEntryReport(
                provider: adapter.provider, providerConversationId: "\(digest)-\(ordinal)",
                title: String(entry.title.prefix(BridgeLimits.maximumTitleLength)), bundleId: adapter.bundleId,
                ordinal: ordinal, unread: entry.unread ? true : nil, position: position
            )
        }
    }
}
