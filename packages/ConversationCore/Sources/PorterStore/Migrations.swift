import Foundation

struct Migration: Sendable {
    let version: Int
    let statements: [String]
}

enum Migrations {
    /// Append only. A shipped migration is never edited; schema changes become a new version.
    static let all: [Migration] = [
        Migration(version: 1, statements: [
            """
            CREATE TABLE preferences (
                key TEXT PRIMARY KEY NOT NULL,
                provider TEXT NOT NULL,
                connector_id TEXT NOT NULL,
                provider_conversation_id TEXT NOT NULL,
                title TEXT NOT NULL,
                canonical_url TEXT,
                profile_alias TEXT,
                pinned INTEGER NOT NULL DEFAULT 0,
                pin_order INTEGER NOT NULL DEFAULT 0,
                hidden INTEGER NOT NULL DEFAULT 0,
                revision INTEGER NOT NULL DEFAULT 1,
                modified_at TEXT NOT NULL,
                modified_by_device TEXT NOT NULL
            )
            """,
            "CREATE INDEX preferences_connector ON preferences (connector_id)",
            "CREATE INDEX preferences_pin_order ON preferences (pinned, pin_order)",
        ]),
    ]

    static func apply(_ migrations: [Migration], to database: SQLiteDatabase) throws(StoreError) {
        let supported = migrations.map(\.version).max() ?? 0
        let current = try database.userVersion()
        guard current <= supported else { throw .newerThanSupported(found: current, supported: supported) }
        for migration in migrations.sorted(by: { $0.version < $1.version }) where migration.version > current {
            try database.transaction("migrate to \(migration.version)") { () throws(StoreError) in
                for statement in migration.statements {
                    try database.execute(statement, context: "migration \(migration.version)")
                }
                try database.setUserVersion(migration.version)
            }
        }
    }
}
