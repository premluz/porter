import ConversationCore
import Foundation

extension PanelBuilder {
    /// When an extension and Porter's own scripting both see the same conversation, the extension's route
    /// wins: it knows the profile and last-used time, and listing both would show one chat twice.
    /// A conversation seen only by scripting stays. If it is also open in a profile without the extension,
    /// that second route is not shown, which is the cost of not guessing which profile a tab is in.
    static func preferringEnhancedRoutes(_ rows: [DestinationRow], connectors: [ConnectorSummary]) -> [DestinationRow] {
        let scripted = Set(connectors.filter { $0.providerType == .chromeScripting }.map(\.connectorId))
        guard !scripted.isEmpty else { return rows }
        let enhanced = Set(rows.filter { !scripted.contains($0.connectorId) }.map { "\($0.provider)/\($0.providerConversationId)" })
        return rows.filter { !scripted.contains($0.connectorId) || !enhanced.contains("\($0.provider)/\($0.providerConversationId)") }
    }
}
