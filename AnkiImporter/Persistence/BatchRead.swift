import Foundation
import SQLite3

/// Date filter options for batch queries.
enum DateFilter: String, CaseIterable {
    case all = "All"
    case week = "This Week"
    case month = "This Month"
}

/// Efficiently loads complete batch data using JOIN queries.
enum BatchRead {
    /// Fetch complete batch data with words and paragraph in optimized queries.
    static func fetchAllBatches(on db: OpaquePointer) throws -> [SavedBatch] {
        try fetchAllBatches(on: db, dateFilter: .all)
    }

    /// Fetch batches with optional date filtering at the SQL level.
    static func fetchAllBatches(on db: OpaquePointer, dateFilter: DateFilter) throws -> [SavedBatch] {
        let batchRows = try fetchBatchRows(db, dateFilter: dateFilter)
        guard !batchRows.isEmpty else { return [] }

        let batchIDs = batchRows.map { String($0.id) }.joined(separator: ",")
        let wordsByBatch = try fetchWordsForBatches(db, batchIDs: batchIDs)
        let paragraphByBatch = try fetchParagraphsForBatches(db, batchIDs: batchIDs)

        return batchRows.map { row in
            SavedBatch(
                id: row.id,
                createdAt: row.createdAt,
                words: wordsByBatch[row.id] ?? [],
                paragraph: paragraphByBatch[row.id] ?? ""
            )
        }
    }

    /// Fetch single batch with all data using JOINs - batch JOIN paragraph JOIN words.
    static func fetchBatchDetail(on db: OpaquePointer, batchID: Int64) throws -> SavedBatch? {
        // Single query joining all three tables: batch + paragraph + words
        let sql = """
        SELECT 
            b.id, b.created_at,
            p.paragraph,
            w.id as word_id, w.word, w.word_type, w.meaning, w.example_1, w.example_2
        FROM batch b
        LEFT JOIN paragraph p ON p.batch_id = b.id
        LEFT JOIN word w ON w.batch_id = b.id
        WHERE b.id = ?
        ORDER BY w.id ASC;
        """
        let stmt = try SQLiteDatabase.prepare(db, sql: sql)
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_bind_int64(stmt, 1, batchID) == SQLITE_OK else {
            throw SQLiteDatabase.sqliteError(db)
        }

        var batchInfo: (id: Int64, createdAt: String, paragraph: String)?
        var words: [SavedBatchWord] = []

        while try SQLiteDatabase.stepRow(stmt, db: db) {
            // Extract batch info from first row
            if batchInfo == nil {
                batchInfo = (
                    id: SQLiteDatabase.columnInt64(stmt, 0),
                    createdAt: SQLiteDatabase.columnText(stmt, 1),
                    paragraph: SQLiteDatabase.columnText(stmt, 2)
                )
            }

            // Extract word if present (word_id will be 0 or NULL if no words)
            let wordID = SQLiteDatabase.columnInt64(stmt, 3)
            if wordID > 0 {
                let word = SavedBatchWord(
                    id: wordID,
                    word: SQLiteDatabase.columnText(stmt, 4),
                    meaning: SQLiteDatabase.columnText(stmt, 6),
                    wordType: SQLiteDatabase.columnText(stmt, 5),
                    example1: SQLiteDatabase.columnText(stmt, 7),
                    example2: SQLiteDatabase.columnText(stmt, 8)
                )
                words.append(word)
            }
        }

        guard let info = batchInfo else {
            return nil
        }

        return SavedBatch(
            id: info.id,
            createdAt: info.createdAt,
            words: words,
            paragraph: info.paragraph
        )
    }

    private struct BatchRow {
        let id: Int64
        let createdAt: String
    }

    private static func fetchBatchRows(_ db: OpaquePointer, dateFilter: DateFilter) throws -> [BatchRow] {
        let sql: String
        switch dateFilter {
        case .all:
            sql = "SELECT id, created_at FROM batch ORDER BY id DESC;"
        case .week:
            sql = """
                SELECT id, created_at FROM batch
                WHERE created_at >= datetime('now', '-7 days')
                ORDER BY id DESC;
                """
        case .month:
            sql = """
                SELECT id, created_at FROM batch
                WHERE created_at >= datetime('now', '-1 month')
                ORDER BY id DESC;
                """
        }

        let stmt = try SQLiteDatabase.prepare(db, sql: sql)
        defer { sqlite3_finalize(stmt) }

        var rows: [BatchRow] = []
        while try SQLiteDatabase.stepRow(stmt, db: db) {
            rows.append(
                BatchRow(
                    id: SQLiteDatabase.columnInt64(stmt, 0),
                    createdAt: SQLiteDatabase.columnText(stmt, 1)
                )
            )
        }
        return rows
    }

    /// Single query to get all words for specific batch IDs using IN clause.
    private static func fetchWordsForBatches(_ db: OpaquePointer, batchIDs: String) throws -> [Int64: [SavedBatchWord]] {
        let sql = """
        SELECT id, batch_id, word, word_type, meaning, example_1, example_2
        FROM word
        WHERE batch_id IN (\(batchIDs))
        ORDER BY batch_id ASC, id ASC;
        """
        let stmt = try SQLiteDatabase.prepare(db, sql: sql)
        defer { sqlite3_finalize(stmt) }

        var map: [Int64: [SavedBatchWord]] = [:]
        while try SQLiteDatabase.stepRow(stmt, db: db) {
            let batchID = SQLiteDatabase.columnInt64(stmt, 1)
            let word = SavedBatchWord(
                id: SQLiteDatabase.columnInt64(stmt, 0),
                word: SQLiteDatabase.columnText(stmt, 2),
                meaning: SQLiteDatabase.columnText(stmt, 4),
                wordType: SQLiteDatabase.columnText(stmt, 3),
                example1: SQLiteDatabase.columnText(stmt, 5),
                example2: SQLiteDatabase.columnText(stmt, 6)
            )
            map[batchID, default: []].append(word)
        }
        return map
    }

    private static func fetchWordsForBatch(_ db: OpaquePointer, batchID: Int64) throws -> [SavedBatchWord] {
        let sql = """
        SELECT id, word, word_type, meaning, example_1, example_2
        FROM word
        WHERE batch_id = ?
        ORDER BY id ASC;
        """
        let stmt = try SQLiteDatabase.prepare(db, sql: sql)
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_bind_int64(stmt, 1, batchID) == SQLITE_OK else {
            throw SQLiteDatabase.sqliteError(db)
        }

        var words: [SavedBatchWord] = []
        while try SQLiteDatabase.stepRow(stmt, db: db) {
            words.append(SavedBatchWord(
                id: SQLiteDatabase.columnInt64(stmt, 0),
                word: SQLiteDatabase.columnText(stmt, 1),
                meaning: SQLiteDatabase.columnText(stmt, 3),
                wordType: SQLiteDatabase.columnText(stmt, 2),
                example1: SQLiteDatabase.columnText(stmt, 4),
                example2: SQLiteDatabase.columnText(stmt, 5)
            ))
        }
        return words
    }

    /// Single query to get all paragraphs for specific batch IDs using IN clause.
    private static func fetchParagraphsForBatches(_ db: OpaquePointer, batchIDs: String) throws -> [Int64: String] {
        let sql = """
        SELECT batch_id, paragraph
        FROM paragraph
        WHERE batch_id IN (\(batchIDs))
        ORDER BY batch_id ASC;
        """
        let stmt = try SQLiteDatabase.prepare(db, sql: sql)
        defer { sqlite3_finalize(stmt) }

        var map: [Int64: String] = [:]
        while try SQLiteDatabase.stepRow(stmt, db: db) {
            let batchID = SQLiteDatabase.columnInt64(stmt, 0)
            let text = SQLiteDatabase.columnText(stmt, 1)
            map[batchID] = text
        }
        return map
    }
}
