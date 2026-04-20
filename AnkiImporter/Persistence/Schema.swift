import Foundation

enum Schema {
    static func install(on db: OpaquePointer) throws {
        try SQLiteDatabase.exec(
            db,
            sql: """
            PRAGMA foreign_keys = ON;

            CREATE TABLE IF NOT EXISTS batch (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );

            CREATE TABLE IF NOT EXISTS word (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                batch_id INTEGER NOT NULL REFERENCES batch(id) ON DELETE CASCADE,
                word TEXT NOT NULL,
                word_type TEXT NOT NULL DEFAULT '',
                meaning TEXT NOT NULL,
                example_1 TEXT NOT NULL DEFAULT '',
                example_2 TEXT NOT NULL DEFAULT ''
            );

            CREATE TABLE IF NOT EXISTS paragraph (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                batch_id INTEGER NOT NULL REFERENCES batch(id) ON DELETE CASCADE,
                paragraph TEXT NOT NULL DEFAULT ''
            );
            """
        )
    }
}
