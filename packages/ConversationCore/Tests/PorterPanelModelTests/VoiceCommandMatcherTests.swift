import ConversationCore
import Foundation
import Testing
@testable import PorterPanelModel

@Suite("Voice targets use panel search without guessing")
struct VoiceCommandMatcherTests {
    @Test("browser titles and profiles retain the panel's all-terms semantics")
    func browserDataset() throws {
        let rows = [Fixture.row("a", title: "Fix login", alias: "Work"),
                    Fixture.row("b", title: "Fix login callback", alias: "Personal"),
                    Fixture.row("c", title: "Release notes", alias: "Work")]
        let items = Fixture.build(rows: rows).navigable
        let expected = try #require(items.first { $0.title == "Fix login" })
        #expect(VoiceCommandMatcher.match(query: "FIX work", in: items) == .single(expected))
        #expect(VoiceCommandMatcher.match(query: "fix logon", in: items) == .none(query: "fix logon"))
        assertMatchesPanel(query: "fix login", rows: rows)
        assertMatchesPanel(query: "claude personal", rows: rows)
    }

    @Test("coding projects with duplicate titles require disambiguation and preserve independent identities")
    func projectDataset() {
        let rows = [projectRow("a", title: "Ship release", project: "Atlas"),
                    projectRow("b", title: "Ship release", project: "Memento"),
                    projectRow("c", title: "C++ parser", project: "Atlas")]
        let items = Fixture.build(rows: rows).navigable
        guard case .multiple(let query, let matches) = VoiceCommandMatcher.match(query: "Ship release", in: items) else {
            Issue.record("Identically named tasks in different projects must require a choice")
            return
        }
        #expect(query == "Ship release")
        #expect(Set(matches.map(\.id)).count == 2)
        #expect(Set(matches.compactMap(\.projectName)) == ["Atlas", "Memento"])
        #expect(VoiceCommandMatcher.match(query: "Atlus", in: items) == .none(query: "Atlus"))
        assertMatchesPanel(query: "ship memento", rows: rows)
        assertMatchesPanel(query: "C++ atlas", rows: rows)
    }

    @Test("no empty query can accidentally select the only item, and closed pins still get click recovery")
    func emptyAndRecovery() {
        let item = Fixture.build(records: [Fixture.record("closed", title: "Recovery")]).navigable[0]
        #expect(VoiceCommandMatcher.match(query: " \n", in: [item]) == .none(query: " \n"))
        #expect(VoiceCommandMatcher.match(query: "Recovery", in: [item]) == .single(item))
        var selection = PanelSelection()
        selection.select(item.id)
        #expect(selection.action(in: [item]) == .showRecovery(item))
    }

    private func assertMatchesPanel(query: String, rows: [DestinationRow]) {
        let items = Fixture.build(rows: rows).navigable
        let expected = Fixture.build(rows: rows, query: query).navigable
        let match = VoiceCommandMatcher.match(query: query, in: items)
        switch match {
        case .none: #expect(expected.isEmpty)
        case .single(let item): #expect(expected == [item])
        case .multiple(let returned, let matches):
            #expect(returned == query)
            #expect(matches == expected)
        }
    }

    private func projectRow(_ id: String, title: String, project: String) -> DestinationRow {
        DestinationRow(
            destinationId: UUID(), revision: 1, conversationId: UUID(), providerConversationId: id, provider: "codex",
            title: title, profileAlias: project, connectorId: Fixture.personal, reachability: .connected,
            tabId: 1, windowId: 1, url: nil, routeCount: 1
        )
    }
}
