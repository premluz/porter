import Foundation

/// Local persistence for pins and hidden items. An actor so one SQLite handle is never shared
/// across threads; every change bumps the record revision and names the device that made it.
public actor PreferenceStore {
    private static let columns = """
        key, provider, connector_id, provider_conversation_id, title, canonical_url, profile_alias,
        pinned, pin_order, hidden, revision, modified_at, modified_by_device
        """
    private static let timestampFormat = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    private let database: SQLiteDatabase
    private let deviceId: UUID

    public static let inMemoryPath = ":memory:"

    public init(path: String, deviceId: UUID) throws(StoreError) {
        try self.init(path: path, deviceId: deviceId, migrations: Migrations.all)
    }

    init(path: String, deviceId: UUID, migrations: [Migration]) throws(StoreError) {
        database = try SQLiteDatabase(path: path)
        self.deviceId = deviceId
        if path != Self.inMemoryPath { try Self.restrictPermissions(path) }
        try Migrations.apply(migrations, to: database)
    }

    public func schemaVersion() throws(StoreError) -> Int { try database.userVersion() }

    public func all() throws(StoreError) -> [PreferenceRecord] {
        var records: [PreferenceRecord] = []
        var failure: StoreError?
        try database.query("SELECT \(Self.columns) FROM preferences ORDER BY pinned DESC, pin_order, key", context: "read preferences") { row in
            do throws(StoreError) { records.append(try Self.record(row)) } catch { failure = error }
        }
        if let failure { throw failure }
        return records
    }

    /// Pins to the end of the pinned list. Pinning an already pinned item keeps its position.
    public func pin(_ snapshot: ConversationSnapshot, at now: Date) throws(StoreError) {
        try database.transaction("pin") { () throws(StoreError) in
            let existing = try find(snapshot.key)
            let order = existing?.pinned == true ? existing?.pinOrder ?? 0 : try nextPinOrder()
            try write(snapshot, pinned: true, pinOrder: order, hidden: existing?.hidden ?? false, at: now)
        }
    }

    public func unpin(_ key: ConversationKey, at now: Date) throws(StoreError) {
        try database.transaction("unpin") { () throws(StoreError) in
            guard let existing = try find(key) else { return }
            if existing.hidden {
                try write(existing.snapshot, pinned: false, pinOrder: 0, hidden: true, at: now)
            } else {
                try delete(key)
            }
        }
    }

    public func hide(_ snapshot: ConversationSnapshot, at now: Date) throws(StoreError) {
        try database.transaction("hide") { () throws(StoreError) in
            let existing = try find(snapshot.key)
            try write(snapshot, pinned: existing?.pinned ?? false, pinOrder: existing?.pinOrder ?? 0, hidden: true, at: now)
        }
    }

    public func unhide(_ key: ConversationKey, at now: Date) throws(StoreError) {
        try database.transaction("unhide") { () throws(StoreError) in
            guard let existing = try find(key) else { return }
            if existing.pinned {
                try write(existing.snapshot, pinned: true, pinOrder: existing.pinOrder, hidden: false, at: now)
            } else {
                try delete(key)
            }
        }
    }

    /// Keys not listed keep their relative order after the listed ones.
    public func reorderPins(_ ordered: [ConversationKey], at now: Date) throws(StoreError) {
        try database.transaction("reorder") { () throws(StoreError) in
            let pinned = try all().filter(\.pinned)
            let listed = ordered.compactMap { key in pinned.first { $0.key == key } }
            let rest = pinned.filter { record in !listed.contains { $0.key == record.key } }
            for (index, record) in (listed + rest).enumerated() where record.pinOrder != index {
                try write(record.snapshot, pinned: true, pinOrder: index, hidden: record.hidden, at: now)
            }
        }
    }

    /// Refreshes display metadata for something the user already kept; never creates a record.
    public func refresh(_ snapshot: ConversationSnapshot, at now: Date) throws(StoreError) {
        try database.transaction("refresh") { () throws(StoreError) in
            guard let existing = try find(snapshot.key), existing.snapshot != snapshot else { return }
            try write(snapshot, pinned: existing.pinned, pinOrder: existing.pinOrder, hidden: existing.hidden, at: now)
        }
    }

    /// Source disconnect (REQ-011): removes only that connector's records.
    public func deleteConnector(_ connectorId: String) throws(StoreError) {
        try database.query("DELETE FROM preferences WHERE connector_id = ?", [.text(connectorId)], context: "delete connector")
    }

    public func deleteAll() throws(StoreError) {
        try database.query("DELETE FROM preferences", context: "delete all")
    }

    private func find(_ key: ConversationKey) throws(StoreError) -> PreferenceRecord? {
        var found: PreferenceRecord?
        var failure: StoreError?
        try database.query("SELECT \(Self.columns) FROM preferences WHERE key = ?", [.text(key.storageKey)], context: "find preference") { row in
            do throws(StoreError) { found = try Self.record(row) } catch { failure = error }
        }
        if let failure { throw failure }
        return found
    }

    private func nextPinOrder() throws(StoreError) -> Int {
        var next = 0
        try database.query("SELECT COALESCE(MAX(pin_order) + 1, 0) FROM preferences WHERE pinned = 1", context: "next pin order") { next = $0.int(0) }
        return next
    }

    private func delete(_ key: ConversationKey) throws(StoreError) {
        try database.query("DELETE FROM preferences WHERE key = ?", [.text(key.storageKey)], context: "delete preference")
    }

    private func write(
        _ snapshot: ConversationSnapshot, pinned: Bool, pinOrder: Int, hidden: Bool, at now: Date
    ) throws(StoreError) {
        let revision = (try find(snapshot.key)?.revision ?? 0) + 1
        let key = snapshot.key
        try database.query("""
            INSERT OR REPLACE INTO preferences (\(Self.columns)) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, [
            .text(key.storageKey), .text(key.provider), .text(key.connectorId), .text(key.providerConversationId),
            .text(snapshot.title), snapshot.canonicalUrl.map(SQLiteValue.text) ?? .null,
            snapshot.profileAlias.map(SQLiteValue.text) ?? .null,
            .integer(pinned ? 1 : 0), .integer(Int64(pinOrder)), .integer(hidden ? 1 : 0), .integer(Int64(revision)),
            .text(now.formatted(Self.timestampFormat)), .text(deviceId.uuidString),
        ], context: "write preference")
    }

    private static func record(_ row: SQLiteRow) throws(StoreError) -> PreferenceRecord {
        let key = try ConversationKey(storageKey: row.requiredText(0))
        guard let modifiedAt = try? timestampFormat.parse(row.requiredText(11)),
              let device = UUID(uuidString: row.requiredText(12)) else {
            throw .invalidKey("unreadable metadata for \(key.storageKey)")
        }
        return PreferenceRecord(
            key: key, title: row.requiredText(4), canonicalUrl: row.text(5), profileAlias: row.text(6),
            pinned: row.int(7) == 1, pinOrder: row.int(8), hidden: row.int(9) == 1, revision: row.int(10),
            modifiedAt: modifiedAt, modifiedByDevice: device
        )
    }

    private static func restrictPermissions(_ path: String) throws(StoreError) {
        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
        } catch {
            throw .fileProtection(path: path, reason: String(describing: error))
        }
    }
}

extension PreferenceRecord {
    var snapshot: ConversationSnapshot {
        ConversationSnapshot(key: key, title: title, canonicalUrl: canonicalUrl, profileAlias: profileAlias)
    }
}
