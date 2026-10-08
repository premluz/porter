import Foundation
import Testing
@testable import PorterStore

@Suite("Store migrations")
struct MigrationTests {
    private func tempPath() -> String {
        NSTemporaryDirectory() + "porter-migrate-\(UUID().uuidString).sqlite"
    }

    @Test("a new database lands on the latest schema version")
    func freshDatabase() async throws {
        let store = try StoreTests.memoryStore()
        #expect(try await store.schemaVersion() == Migrations.all.map(\.version).max())
    }

    @Test("a database from an older version upgrades and keeps its data")
    func upgradeKeepsData() async throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let v1 = try PreferenceStore(path: path, deviceId: StoreTests.device, migrations: [Migrations.all[0]])
        try await v1.pin(StoreTests.snapshot("a"), at: StoreTests.t0)
        let addedColumn = Migration(version: 2, statements: ["ALTER TABLE preferences ADD COLUMN note TEXT"])
        let v2 = try PreferenceStore(path: path, deviceId: StoreTests.device, migrations: [Migrations.all[0], addedColumn])
        #expect(try await v2.schemaVersion() == 2)
        #expect(try await v2.all().count == 1)
    }

    @Test("a database written by a newer app is refused, not opened")
    func newerRefused() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let future = Migration(version: 5, statements: ["CREATE TABLE preferences (key TEXT)"])
        _ = try PreferenceStore(path: path, deviceId: StoreTests.device, migrations: [future])
        #expect(throws: StoreError.newerThanSupported(found: 5, supported: 1)) {
            try PreferenceStore(path: path, deviceId: StoreTests.device)
        }
    }

    @Test("a failing migration rolls back completely")
    func failedMigrationRollsBack() async throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let broken = Migration(version: 1, statements: ["CREATE TABLE ok (id INTEGER)", "THIS IS NOT SQL"])
        #expect(throws: StoreError.self) { try PreferenceStore(path: path, deviceId: StoreTests.device, migrations: [broken]) }
        let retry = try PreferenceStore(path: path, deviceId: StoreTests.device, migrations: [
            Migration(version: 1, statements: ["CREATE TABLE ok (id INTEGER)"]),
        ])
        #expect(try await retry.schemaVersion() == 1)
    }

    @Test("an unusable path is an error with context, not a crash")
    func badPath() {
        #expect(throws: StoreError.self) {
            try PreferenceStore(path: "/nonexistent-directory/porter.sqlite", deviceId: StoreTests.device)
        }
    }
}
