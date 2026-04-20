import Foundation

enum BatchStoreError: LocalizedError {
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .validation(let message):
            return message
        }
    }
}

@MainActor
final class BatchStore {
    static let shared = BatchStore()

    private let sqlite: SQLiteDatabase

    private init() {
        sqlite = SQLiteDatabase(url: Self.databaseURL())
    }

    func initialize() throws {
        try sqlite.withConnection { db in
            try Schema.install(on: db)
        }
    }

    func saveBatch(words: [BatchWordInput], paragraph: String) throws -> Int64 {
        guard !words.isEmpty else {
            throw BatchStoreError.validation("Add at least one word before submitting.")
        }
        return try sqlite.withConnection { db in
            try BatchSQL.saveBatch(on: db, words: words, paragraph: paragraph)
        }
    }

    func loadSavedBatches(dateFilter: DateFilter = .all) throws -> [SavedBatch] {
        try sqlite.withConnection { db in
            try BatchRead.fetchAllBatches(on: db, dateFilter: dateFilter)
        }
    }

    /// `anki_mate.db` next to the running executable (e.g. `.build/.../debug/` or `MyApp.app/Contents/MacOS/`).
    private static func databaseURL() -> URL {
        if let dir = Bundle.main.executableURL?.deletingLastPathComponent() {
            return dir.appendingPathComponent("anki_mate.db")
        }
        // Rare fallback (e.g. tests): Application Support
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = base.appendingPathComponent("AnkiImporter", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("anki_mate.db")
    }
}
