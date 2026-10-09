import ConversationCore
import Foundation

/// One tab as the scripted list reports it, before a recognizer decides whether it is a conversation.
struct ScriptedTab: Equatable {
    let windowIndex: Int
    let windowId: Int
    let activeTabIndex: Int
    let position: Int
    let tabId: Int
    let url: String
    let title: String

    var isActive: Bool { position == activeTabIndex }
    var isInFrontWindow: Bool { windowIndex == 1 }
}

enum ChromiumTabParser {
    /// Records that cannot be read are counted, not guessed at, so the caller can say so.
    static func parse(_ output: String) -> (tabs: [ScriptedTab], unreadable: Int) {
        var tabs: [ScriptedTab] = []
        var unreadable = 0
        for record in output.split(separator: ChromiumScripts.recordSeparator, omittingEmptySubsequences: true) {
            let fields = record.split(separator: ChromiumScripts.fieldSeparator, maxSplits: 6, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard fields.count == 7, let windowIndex = Int(fields[0]), let windowId = Int(fields[1]),
                  let active = Int(fields[2]), let position = Int(fields[3]), let tabId = Int(fields[4]) else {
                unreadable += 1
                continue
            }
            tabs.append(ScriptedTab(
                windowIndex: windowIndex, windowId: windowId, activeTabIndex: active, position: position,
                tabId: tabId, url: fields[5], title: fields[6]
            ))
        }
        return (tabs, unreadable)
    }

    /// Only tabs a recognizer accepts become reports; everything else is dropped here as well as in the script.
    static func reports(_ tabs: [ScriptedTab], recency: (ScriptedTab) -> Date?) -> [(tab: ScriptedTab, report: TabReport)] {
        tabs.compactMap { tab in
            guard let (recognizer, match) = ProviderRecognizers.recognize(url: tab.url) else { return nil }
            return (tab, TabReport(
                tabId: tab.tabId, windowId: tab.windowId, provider: recognizer.provider,
                providerConversationId: match.providerConversationId, title: recognizer.cleanTitle(tab.title),
                canonicalUrl: match.canonicalUrl, lastActiveAt: recency(tab)
            ))
        }
    }
}
