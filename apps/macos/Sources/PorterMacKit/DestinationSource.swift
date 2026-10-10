import BridgeTransport
import ConversationCore
import Foundation
import NativeSources
import Synchronization

/// Where the panel gets its routes. The live source is the embedded registry; the fixture source
/// shows every state without a browser.
public protocol DestinationSource: Sendable {
    func listing() -> RegistryListing
    /// Only states backed by a verified signal; a route with none is simply absent, which reads as Unknown.
    func statuses() -> [UUID: DestinationStatus]
    func activate(destinationId: UUID, revision: Int) async -> ActivationReport
    func setChangeHandler(_ handler: @escaping @Sendable () -> Void)
    /// What the setup window shows. Sample data has no sources, so it reports none.
    func setupInputs() -> SetupInputs
}

extension DestinationSource {
    public func setupInputs() -> SetupInputs { SetupInputs() }
}

final class ChangeRelay: Sendable {
    private let handler = Mutex<(@Sendable () -> Void)?>(nil)

    func set(_ newHandler: @escaping @Sendable () -> Void) {
        handler.withLock { $0 = newHandler }
    }

    func fire() {
        handler.withLock { $0 }?()
    }
}

public final class LiveRegistrySource: DestinationSource {
    private let service: RegistryService
    private let relay: ChangeRelay
    private let log: @Sendable (String) -> Void
    private let nativeSessions = Mutex<[LocalConnectorSession]>([])
    private let chromeScripting = Mutex<ChromeScriptingConnector?>(nil)
    private let desktopApps = Mutex<DesktopAppConnector?>(nil)
    private let codexThreads = Mutex<CodexThreadsConnector?>(nil)
    private let assets = BundledAssets.from()

    public init(log: @escaping @Sendable (String) -> Void) {
        let relay = ChangeRelay()
        self.relay = relay
        self.log = log
        service = RegistryService(
            deviceId: UUID(), log: log, focusApplication: { ChromeFocus.requestForeground() },
            onChange: { relay.fire() }, bindingsPath: PorterPaths.supportDirectory() + "/agent-bindings.json"
        )
    }

    public func start() throws(SocketError) {
        try service.start(bridgePath: PorterPaths.bridgeSocket(), controlPath: PorterPaths.controlSocket())
    }

    /// Starts the sources that read other applications directly, with no extension. A source that is not
    /// allowed or not running simply reports nothing; its state is in `nativeHealth`.
    public func attachNativeSources(defaults: UserDefaults = .standard) {
        let chrome = ChromeScriptingConnector(installationId: Self.installationId(named: "chromeScripting", defaults: defaults))
        let apps = DesktopAppConnector(installationId: Self.installationId(named: "desktopApp", defaults: defaults))
        let codex = CodexThreadsConnector(installationId: Self.installationId(named: "codexThreads", defaults: defaults))
        for connector: any HostConnector in [chrome, apps, codex] {
            do {
                let session = try service.attach(connector)
                nativeSessions.withLock { $0.append(session) }
            } catch {
                log("native source \(connector.kind.rawValue) could not start: \(error)")
            }
        }
        chromeScripting.withLock { $0 = chrome }
        desktopApps.withLock { $0 = apps }
        codexThreads.withLock { $0 = codex }
    }

    public var nativeHealth: [String: SourceHealth] {
        var health: [String: SourceHealth] = [:]
        if let chrome = chromeScripting.withLock({ $0 }) { health["chromeScripting"] = chrome.health }
        for (provider, value) in desktopApps.withLock({ $0 })?.health ?? [:] { health[provider] = value }
        // Codex's thread list is a file read, so it is either there or Codex is not installed (no row then).
        if let codex = codexThreads.withLock({ $0 }), codex.isAvailable { health["codex"] = .ready }
        return health
    }

    /// A source keeps one identity across launches, so the registry sees a restart, not a new connector.
    private static func installationId(named name: String, defaults: UserDefaults) -> UUID {
        let key = "porter.source.\(name).installationId"
        if let stored = defaults.string(forKey: key).flatMap(UUID.init(uuidString:)) { return stored }
        let created = UUID()
        defaults.set(created.uuidString, forKey: key)
        return created
    }

    public func setupInputs() -> SetupInputs {
        let health = nativeHealth
        return SetupInputs(
            chrome: health["chromeScripting"], claudeApp: health["claude-desktop"], chatgptApp: health["chatgpt-desktop"],
            codexThreads: health["codex"],
            connectors: service.listing().connectors, installedEditors: SetupEnvironment.installedEditors().map(\.name),
            claudeCodeHook: SetupEnvironment.claudeCodeHookInstalled(),
            canInstallCompanion: assets.vsix != nil, canEnableClaudeCodeStatus: assets.hookScript != nil && assets.porterctl != nil,
            canSetUpChromeExtension: assets.nativeHost != nil && assets.chromeExtensionFolder != nil,
            launchAtLogin: LiveLoginItem().state
        )
    }

    public func listing() -> RegistryListing { service.listing() }

    /// Only what the registry can attribute with certainty: Claude Code tabs it has hook events for.
    public func statuses() -> [UUID: DestinationStatus] { service.statuses() }

    public func activate(destinationId: UUID, revision: Int) async -> ActivationReport {
        // The registry blocks until the browser answers, so keep it off the main thread.
        let service = service
        return await Task.detached { service.activate(destinationId: destinationId, expectedRevision: revision) }.value
    }

    public func setChangeHandler(_ handler: @escaping @Sendable () -> Void) {
        relay.set(handler)
    }
}
