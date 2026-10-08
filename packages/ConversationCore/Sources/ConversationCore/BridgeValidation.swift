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

    static func validate(_ snapshot: InventorySnapshotPayload) throws(EnvelopeRejection) {
        guard snapshot.tabs.count <= BridgeLimits.maximumTabsPerSnapshot else {
            throw .malformed("snapshot has \(snapshot.tabs.count) tabs")
        }
        guard Set(snapshot.tabs.map(\.tabId)).count == snapshot.tabs.count else {
            throw .malformed("duplicate tab id in snapshot")
        }
        for tab in snapshot.tabs { try validate(tab) }
    }
}
