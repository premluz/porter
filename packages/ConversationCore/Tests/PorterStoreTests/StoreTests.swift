import Foundation
import Testing
@testable import PorterStore

@Suite("Preference store")
struct StoreTests {
    static let device = UUID()
    static let t0 = Date(timeIntervalSince1970: 1_791_450_000)

    static func key(_ chat: String, connector: String = "chrome-aaa") throws -> ConversationKey {
        try ConversationKey(provider: "claude", connectorId: connector, providerConversationId: chat)
    }

    static func snapshot(_ chat: String, connector: String = "chrome-aaa", title: String = "Plan") throws -> ConversationSnapshot {
        ConversationSnapshot(
            key: try key(chat, connector: connector), title: title,
            canonicalUrl: "https://claude.ai/chat/\(chat)", profileAlias: "Work"
        )
    }

    static func memoryStore() throws -> PreferenceStore {
        try PreferenceStore(path: PreferenceStore.inMemoryPath, deviceId: device)
    }

    @Test("pins keep their order and persist display metadata")
    func pinOrder() async throws {
        let store = try Self.memoryStore()
        try await store.pin(Self.snapshot("a"), at: Self.t0)
        try await store.pin(Self.snapshot("b"), at: Self.t0)
        try await store.pin(Self.snapshot("a"), at: Self.t0)
        let pinned = try await store.all().filter(\.pinned)
        #expect(pinned.map(\.key.providerConversationId) == ["a", "b"])
        #expect(pinned.first?.title == "Plan")
        #expect(pinned.first?.canonicalUrl == "https://claude.ai/chat/a")
    }

    @Test("an ordinary conversation is never stored")
    func nothingStoredByDefault() async throws {
        let store = try Self.memoryStore()
        try await store.refresh(Self.snapshot("a"), at: Self.t0)
        #expect(try await store.all().isEmpty)
    }

    @Test("unpinning removes the record unless it is also hidden")
    func unpin() async throws {
        let store = try Self.memoryStore()
        try await store.pin(Self.snapshot("a"), at: Self.t0)
        try await store.hide(Self.snapshot("a"), at: Self.t0)
        try await store.unpin(Self.key("a"), at: Self.t0)
        let afterUnpin = try await store.all()
        #expect(afterUnpin.count == 1 && afterUnpin[0].hidden && !afterUnpin[0].pinned)
        try await store.unhide(Self.key("a"), at: Self.t0)
        #expect(try await store.all().isEmpty)
    }

    @Test("reordering moves listed pins first and keeps the rest in order")
    func reorder() async throws {
        let store = try Self.memoryStore()
        for chat in ["a", "b", "c"] { try await store.pin(Self.snapshot(chat), at: Self.t0) }
        try await store.reorderPins([Self.key("c")], at: Self.t0)
        #expect(try await store.all().filter(\.pinned).map(\.key.providerConversationId) == ["c", "a", "b"])
    }

    @Test("refresh updates the title of something already kept and bumps the revision")
    func refresh() async throws {
        let store = try Self.memoryStore()
        try await store.pin(Self.snapshot("a"), at: Self.t0)
        try await store.refresh(Self.snapshot("a", title: "Renamed"), at: Self.t0.addingTimeInterval(5))
        let record = try #require(try await store.all().first)
        #expect(record.title == "Renamed")
        #expect(record.revision == 2)
        #expect(record.modifiedByDevice == Self.device)
    }

    @Test("the same chat reached from two profiles is two separate pins")
    func profilesAreSeparate() async throws {
        let store = try Self.memoryStore()
        try await store.pin(Self.snapshot("a", connector: "chrome-one"), at: Self.t0)
        try await store.pin(Self.snapshot("a", connector: "chrome-two"), at: Self.t0)
        #expect(try await store.all().count == 2)
    }

    @Test("disconnecting a source deletes only its records")
    func deleteConnector() async throws {
        let store = try Self.memoryStore()
        try await store.pin(Self.snapshot("a", connector: "chrome-one"), at: Self.t0)
        try await store.pin(Self.snapshot("b", connector: "chrome-two"), at: Self.t0)
        try await store.deleteConnector("chrome-one")
        #expect(try await store.all().map(\.key.connectorId) == ["chrome-two"])
    }

    @Test("keys reject separators and unexpected characters")
    func invalidKeys() {
        for bad in ["", "a/b", "a b", "naïve", String(repeating: "x", count: 129)] {
            #expect(throws: StoreError.invalidKey(bad)) {
                try ConversationKey(provider: "claude", connectorId: "chrome-a", providerConversationId: bad)
            }
        }
        #expect(throws: StoreError.self) { try ConversationKey(storageKey: "only/two") }
    }

    @Test("records survive reopening the file, which is owner-only")
    func persistence() async throws {
        let path = NSTemporaryDirectory() + "porter-store-\(UUID().uuidString).sqlite"
        defer { try? FileManager.default.removeItem(atPath: path) }
        let first = try PreferenceStore(path: path, deviceId: Self.device)
        try await first.pin(Self.snapshot("a"), at: Self.t0)
        let second = try PreferenceStore(path: path, deviceId: Self.device)
        #expect(try await second.all().count == 1)
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        #expect((attributes[.posixPermissions] as? Int) == 0o600)
    }
}
