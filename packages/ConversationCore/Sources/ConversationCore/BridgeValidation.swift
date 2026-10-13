import Foundation

/// Semantic limits the JSON Schema also states. Decoding alone accepts additive fields for
/// minor-version compatibility, so size and charset rules are enforced here as well.
enum BridgeValidation {
    private static let identifierCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-"
    )
    private static let providerLength = 2...32

    static func isIdentifier(_ text: String) -> Bool {
        (1...BridgeLimits.maximumIdentifierLength).contains(text.count)
            && text.unicodeScalars.allSatisfy(identifierCharacters.contains)
    }

    static func isProvider(_ text: String) -> Bool {
        providerLength.contains(text.count) && text.wholeMatch(of: /[a-z][a-z0-9-]+/) != nil
    }

    static func isLabel(_ text: String) -> Bool {
        (1...BridgeLimits.maximumLabelLength).contains(text.trimmingCharacters(in: .whitespaces).count)
    }

    static func validate(_ hello: HelloPayload) throws(EnvelopeRejection) {
        if let alias = hello.profileAlias, !isLabel(alias) { throw .malformed("profileAlias length") }
        guard hello.adapterVersions.count <= BridgeLimits.maximumAdapterCount else {
            throw .malformed("too many adapters")
        }
        for (provider, version) in hello.adapterVersions {
            guard isProvider(provider), version.wholeMatch(of: /[0-9]+\.[0-9]+(\.[0-9]+)?/) != nil else {
                throw .malformed("adapter entry \(provider)")
            }
        }
    }

    static func validate(_ tab: TabReport) throws(EnvelopeRejection) {
        guard tab.tabId >= 0, tab.windowId >= 0 else { throw .malformed("negative tab or window id") }
        guard isProvider(tab.provider), isIdentifier(tab.providerConversationId) else {
            throw .malformed("provider or conversation id")
        }
        guard (1...BridgeLimits.maximumTitleLength).contains(tab.title.count) else {
            throw .malformed("title length")
        }
    }

    static func isWorkspacePath(_ text: String) -> Bool {
        text.count >= 2 && text.count <= 1_024 && text.hasPrefix("/") && !text.contains("\0")
            && !text.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    static func validate(_ tab: EditorTabReport) throws(EnvelopeRejection) {
        guard isProvider(tab.provider), isIdentifier(tab.providerConversationId) else {
            throw .malformed("provider or conversation id")
        }
        guard (1...BridgeLimits.maximumTitleLength).contains(tab.title.count) else { throw .malformed("title length") }
        guard isWorkspacePath(tab.workspacePath) else { throw .malformed("workspace path") }
        guard (1...8).contains(tab.viewColumn), (0...8).contains(tab.index) else { throw .malformed("editor position") }
    }

    static func validate(_ entry: AppEntryReport) throws(EnvelopeRejection) {
        guard isProvider(entry.provider), isIdentifier(entry.providerConversationId) else {
            throw .malformed("provider or conversation id")
        }
        guard (1...BridgeLimits.maximumTitleLength).contains(entry.title.count) else { throw .malformed("title length") }
        guard LocatorPolicy.desktopAppBundleIds.contains(entry.bundleId) else { throw .malformed("unsupported app") }
        guard (0..<BridgeLimits.maximumTabsPerSnapshot).contains(entry.ordinal) else { throw .malformed("entry ordinal") }
        if let path = entry.workspacePath, !isWorkspacePath(path) { throw .malformed("workspace path") }
        guard (entry.lastTurnEndedAt == nil) == (entry.lastTurnEndKind == nil) else {
            throw .malformed("turn end needs both timestamp and kind")
        }
    }

    static func validate(_ snapshot: InventorySnapshotPayload) throws(EnvelopeRejection) {
        let appEntries = snapshot.appEntries ?? []
        guard appEntries.count <= BridgeLimits.maximumTabsPerSnapshot else {
            throw .malformed("snapshot has \(appEntries.count) app entries")
        }
        guard Set(appEntries.map(\.providerConversationId)).count == appEntries.count else {
            throw .malformed("duplicate app entry id in snapshot")
        }
        for entry in appEntries { try validate(entry) }
        let editorTabs = snapshot.editorTabs ?? []
        guard editorTabs.count <= BridgeLimits.maximumTabsPerSnapshot else {
            throw .malformed("snapshot has \(editorTabs.count) editor tabs")
        }
        guard Set(editorTabs.map(\.providerConversationId)).count == editorTabs.count else {
            throw .malformed("duplicate editor tab id in snapshot")
        }
        for tab in editorTabs { try validate(tab) }
        try validateBrowserTabs(snapshot)
    }

    private static func validateBrowserTabs(_ snapshot: InventorySnapshotPayload) throws(EnvelopeRejection) {
        guard snapshot.tabs.count <= BridgeLimits.maximumTabsPerSnapshot else {
            throw .malformed("snapshot has \(snapshot.tabs.count) tabs")
        }
        guard Set(snapshot.tabs.map(\.tabId)).count == snapshot.tabs.count else {
            throw .malformed("duplicate tab id in snapshot")
        }
        for tab in snapshot.tabs { try validate(tab) }
    }
}
