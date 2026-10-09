import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("A chat's project and assistant, for the pill and the logo")
struct ProjectAndBrandTests {
    private func item(provider: String, alias: String?) -> PanelItem {
        let row = DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: "a", provider: provider,
            title: "T", profileAlias: alias, connectorId: Fixture.personal, reachability: .connected, tabId: 1,
            windowId: 1, url: nil, routeCount: 1
        )
        return Fixture.build(rows: [row]).open[0]
    }

    @Test("a coding agent in an editor is named by its folder; browser and app chats have no project")
    func projects() {
        #expect(item(provider: "claude-code", alias: "Amble").projectName == "Amble")
        #expect(item(provider: "codex", alias: "Bastion").projectName == "Bastion")
        #expect(item(provider: "claude", alias: "Prem").projectName == nil)
        #expect(item(provider: "chatgpt", alias: "Prem").projectName == nil)
        #expect(item(provider: "claude-desktop", alias: nil).projectName == nil)
        #expect(item(provider: "claude-code", alias: nil).projectName == nil)
    }

    @Test("Claude Code and the Claude app share Claude's logo; Codex and the ChatGPT app share ChatGPT's")
    func brands() {
        for provider in ["claude", "claude-code", "claude-desktop"] { #expect(ProviderNames.brand(for: provider) == .claude) }
        for provider in ["chatgpt", "codex", "chatgpt-desktop"] { #expect(ProviderNames.brand(for: provider) == .chatgpt) }
        #expect(ProviderNames.brand(for: "something-new") == .other)
    }
}
