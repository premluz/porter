import Foundation

/// How Porter observes and activates conversations in one application: a browser, an editor, a desktop
/// chat app. Implementations decide what they can see; the registry decides what it means. Whatever
/// a host cannot tell (a browser profile, a last-used time) is simply left out of its reports, and the
/// registry shows it as unknown.
///
/// Out-of-process connectors (the Chrome extension, the VS Code companion) are the same thing spoken
/// over the bridge socket; a conforming type runs inside the app and joins the registry the same way.
public protocol HostConnector: Sendable {
    var kind: ConnectorKind { get }
    /// Stable for this host on this Mac, so a restart is recognised as the same connector.
    var installationId: UUID { get }
    var profileAlias: String? { get }
    var adapterVersions: [String: String] { get }
    /// Everything this host currently shows that a recognizer accepts; never general browsing.
    func snapshot() async throws -> InventorySnapshotPayload
    /// Brings the target forward after re-checking it is still what the request expects.
    func activate(_ request: ActivateRequestPayload) async -> ActivationOutcome
    /// Yields whenever what the host shows may have changed; the registry then asks for a snapshot.
    func changes() -> AsyncStream<Void>
}
