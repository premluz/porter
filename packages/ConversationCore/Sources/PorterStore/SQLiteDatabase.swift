import Foundation
import SQLite3

/// A minimal wrapper over the system SQLite. Not thread-safe: callers own one instance and
/// serialize access (the store does this by being an actor).
final class SQLiteDatabase {
    private var handle: OpaquePointer?

    init(path: String) throws(StoreError) {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
            let error = Self.error(handle, context: "open \(path)")
            sqlite3_close(handle)
            throw error
        }
    }

    deinit { sqlite3_close(handle) }

    func execute(_ sql: String, context: String) throws(StoreError) {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw Self.error(handle, context: context)
        }
    }

    func transaction<T>(_ context: String, _ body: () throws(StoreError) -> T) throws(StoreError) -> T {
        try execute("BEGIN IMMEDIATE", context: "begin \(context)")
        do {
            let value = try body()
            try execute("COMMIT", context: "commit \(context)")
            return value
        } catch {
            sqlite3_exec(handle, "ROLLBACK", nil, nil, nil)
            throw error
        }
    }

    func userVersion() throws(StoreError) -> Int {
        var version = 0
        try query("PRAGMA user_version", context: "read user_version") { row in version = row.int(0) }
        return version
    }

    func setUserVersion(_ version: Int) throws(StoreError) {
        try execute("PRAGMA user_version = \(version)", context: "write user_version")
    }

    /// Binds positional parameters, runs the statement once and calls `onRow` for each result row.
    func query(
        _ sql: String, _ parameters: [SQLiteValue] = [], context: String,
        onRow: (SQLiteRow) -> Void = { _ in }
    ) throws(StoreError) {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw Self.error(handle, context: "prepare \(context)")
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in parameters.enumerated() {
            let position = Int32(index + 1)
            let status: Int32 = switch value {
            case .integer(let number): sqlite3_bind_int64(statement, position, number)
            case .text(let text): bindText(text, at: position, in: statement)
            case .null: sqlite3_bind_null(statement, position)
            }
            guard status == SQLITE_OK else { throw Self.error(handle, context: "bind \(context)") }
        }
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW: onRow(SQLiteRow(statement: statement))
            case SQLITE_DONE: return
            default: throw Self.error(handle, context: "step \(context)")
            }
        }
    }

    /// SQLite takes ownership of the duplicated string and frees it when the statement is done,
    /// so no lifetime assumptions about Swift's temporary C string are needed.
    private func bindText(_ text: String, at position: Int32, in statement: OpaquePointer?) -> Int32 {
        guard let copy = strdup(text) else { return SQLITE_NOMEM }
        return sqlite3_bind_text(statement, position, copy, -1) { pointer in free(pointer) }
    }

    private static func error(_ handle: OpaquePointer?, context: String) -> StoreError {
        .sqlite(
            code: sqlite3_extended_errcode(handle),
            message: handle.map { String(cString: sqlite3_errmsg($0)) } ?? "no database handle",
            context: context
        )
    }
}

enum SQLiteValue {
    case integer(Int64)
    case text(String)
    case null
}

struct SQLiteRow {
    fileprivate let statement: OpaquePointer?

    func int(_ column: Int32) -> Int { Int(sqlite3_column_int64(statement, column)) }

    func text(_ column: Int32) -> String? {
        sqlite3_column_text(statement, column).map { String(cString: $0) }
    }

    func requiredText(_ column: Int32) -> String { text(column) ?? "" }
}
