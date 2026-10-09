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

    public init(log: @escaping @Sendable (String) -> Void) {
        let relay = ChangeRelay()
        self.relay = relay
        self.log = log
        service = RegistryService(
            deviceId: UUID(), log: log, focusApplication: { ChromeFocus.requestForeground() },
            onChange: { relay.fire() }
        )
    }

    public func start() throws(SocketError) {
        try service.start(bridgePath: PorterPaths.bridgeSocket(), controlPath: PorterPaths.controlSocket())
    }

    /// Starts the sources that read other applications directly, with no extension. A source that is not
    /// allowed or not running simply reports nothing; its state is in `nativeHealth`.
    public func attachNativeSources(defaults: UserDefaults = .standard) {
        let connector = ChromeScriptingConnector(installationId: Self.installationId(named: "chromeScripting", defaults: defaults))
        do {
            let session = try service.attach(connector)
            nativeSessions.withLock { $0.append(session) }
            chromeScripting.withLock { $0 = connector }
        } catch {
            log("native source chromeScripting could not start: \(error)")
        }
    }

    public var nativeHealth: [String: SourceHealth] {
        chromeScripting.withLock { $0 }.map { ["chromeScripting": $0.health] } ?? [:]
    }

    /// A source keeps one identity across launches, so the registry sees a restart, not a new connector.
    private static func installationId(named name: String, defaults: UserDefaults) -> UUID {
        let key = "porter.source.\(name).installationId"
        if let stored = defaults.string(forKey: key).flatMap(UUID.init(uuidString:)) { return stored }
        let created = UUID()
        defaults.set(created.uuidString, forKey: key)
        return created
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
