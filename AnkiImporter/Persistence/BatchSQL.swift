import Foundation
import SQLite3

enum BatchSQL {
    /// Inserts one `batch`, related `word` rows, and one `paragraph` inside a single transaction.
    static func saveBatch(on db: OpaquePointer, words: [BatchWordInput], paragraph: String) throws -> Int64 {
        try SQLiteDatabase.exec(db, sql: "BEGIN IMMEDIATE TRANSACTION;")
        var committed = false
        defer {
            if !committed {
                _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            }
        }

        let batchID = try insertBatch(db)
        try insertWords(db, batchID: batchID, words: words)
        try insertParagraph(db, batchID: batchID, paragraph: paragraph)
        try SQLiteDatabase.exec(db, sql: "COMMIT;")
        committed = true
        return batchID
    }

    private static func insertBatch(_ db: OpaquePointer) throws -> Int64 {
        let statement = try SQLiteDatabase.prepare(db, sql: "INSERT INTO batch DEFAULT VALUES;")
        defer { sqlite3_finalize(statement) }
        try SQLiteDatabase.stepDone(statement, db: db)
        return sqlite3_last_insert_rowid(db)
    }

    private static func insertWords(_ db: OpaquePointer, batchID: Int64, words: [BatchWordInput]) throws {
        let sql = """
        INSERT INTO word (batch_id, word, word_type, meaning, example_1, example_2)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        let statement = try SQLiteDatabase.prepare(db, sql: sql)
        defer { sqlite3_finalize(statement) }

        for item in words {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)

            guard sqlite3_bind_int64(statement, 1, batchID) == SQLITE_OK else {
                throw SQLiteDatabase.sqliteError(db)
            }
            try SQLiteDatabase.bindText(statement, index: 2, value: item.word)
            try SQLiteDatabase.bindText(statement, index: 3, value: item.wordType)
            try SQLiteDatabase.bindText(statement, index: 4, value: item.meaning)
            try SQLiteDatabase.bindText(statement, index: 5, value: item.example1)
            try SQLiteDatabase.bindText(statement, index: 6, value: item.example2)
            try SQLiteDatabase.stepDone(statement, db: db)
        }
    }

    private static func insertParagraph(_ db: OpaquePointer, batchID: Int64, paragraph: String) throws {
        let statement = try SQLiteDatabase.prepare(
            db,
            sql: "INSERT INTO paragraph (batch_id, paragraph) VALUES (?, ?);"
        )
        defer { sqlite3_finalize(statement) }

        guard sqlite3_bind_int64(statement, 1, batchID) == SQLITE_OK else {
            throw SQLiteDatabase.sqliteError(db)
        }
        try SQLiteDatabase.bindText(statement, index: 2, value: paragraph)
        try SQLiteDatabase.stepDone(statement, db: db)
    }
}
