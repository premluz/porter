import ConversationCore
import Foundation

extension PanelBuilder {
    /// When an extension and Porter's own scripting both see the same conversation, the extension's route
    /// wins: it knows the profile and last-used time, and listing both would show one chat twice.
    /// A conversation seen only by scripting stays. If it is also open in a profile without the extension,
    /// that second route is not shown, which is the cost of not guessing which profile a tab is in.
    static func preferringEnhancedRoutes(_ rows: [DestinationRow], connectors: [ConnectorSummary]) -> [DestinationRow] {
        preferringScriptedExtensions(supersededByThreadList(rows, connectors: connectors), connectors: connectors)
    }

    /// Codex's own thread list covers every thread, whether it is open as an editor tab, in the side panel or in the
    /// app, so while it is listed an editor window's Codex tab would only repeat one of its threads.
    private static func supersededByThreadList(_ rows: [DestinationRow], connectors: [ConnectorSummary]) -> [DestinationRow] {
        let listing = Set(connectors.filter { $0.providerType == .desktopApp }.map(\.connectorId))
        let editors = Set(connectors.filter { $0.providerType == .vscodeExtension }.map(\.connectorId))
        guard rows.contains(where: { $0.provider == "codex" && listing.contains($0.connectorId) }) else { return rows }
        return rows.filter { !($0.provider == "codex" && editors.contains($0.connectorId)) }
    }

    private static func preferringScriptedExtensions(_ rows: [DestinationRow], connectors: [ConnectorSummary]) -> [DestinationRow] {
        let scripted = Set(connectors.filter { $0.providerType == .chromeScripting }.map(\.connectorId))
        guard !scripted.isEmpty else { return rows }
        let enhanced = Set(rows.filter { !scripted.contains($0.connectorId) }.map { "\($0.provider)/\($0.providerConversationId)" })
        return rows.filter { !scripted.contains($0.connectorId) || !enhanced.contains("\($0.provider)/\($0.providerConversationId)") }
    }
}
