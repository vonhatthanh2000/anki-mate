import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Opens the DB file, runs `PRAGMA foreign_keys`, and exposes small helpers used by schema and batch SQL.
struct SQLiteDatabase {
    let url: URL

    func withConnection<T>(_ operation: (OpaquePointer) throws -> T) throws -> T {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open database."
            sqlite3_close(db)
            throw DatabaseError.open(message)
        }
        defer { sqlite3_close(db) }

        guard let handle = db else {
            throw DatabaseError.open("Database pointer was nil.")
        }

        guard sqlite3_exec(handle, "PRAGMA foreign_keys = ON;", nil, nil, nil) == SQLITE_OK else {
            throw Self.sqliteError(handle)
        }

        return try operation(handle)
    }

    static func exec(_ db: OpaquePointer, sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(db)
        }
    }

    static func prepare(_ db: OpaquePointer, sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError(db)
        }
        return statement
    }

    static func bindText(_ statement: OpaquePointer?, index: Int32, value: String) throws {
        guard sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
            throw DatabaseError.sqlite("Could not bind text parameter.")
        }
    }

    static func stepDone(_ statement: OpaquePointer?, db: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw sqliteError(db)
        }
    }

    static func sqliteError(_ db: OpaquePointer) -> DatabaseError {
        let message = String(cString: sqlite3_errmsg(db))
        return .sqlite(message)
    }
}
