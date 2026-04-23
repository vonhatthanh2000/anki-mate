import Foundation

enum BatchStoreError: LocalizedError {
    case validation(String)
    case supabaseError(String)

    var errorDescription: String? {
        switch self {
        case .validation(let message):
            return message
        case .supabaseError(let message):
            return "Database error: \(message)"
        }
    }
}

/// Date filter options for batch queries.
enum DateFilter: String, CaseIterable {
    case all = "All"
    case week = "This Week"
    case month = "This Month"
}

@MainActor
final class SupabaseStore {
    static let shared = SupabaseStore()

    private let url: URL
    private let apiKey: String

    private init() {
        // Load credentials from .env file or environment variables
        let env = Self.loadEnvFile()

        let supabaseURLString = ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? env["SUPABASE_URL"]
            ?? "https://your-project.supabase.co"

        let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? env["SUPABASE_ANON_KEY"]
            ?? "your-anon-key"

        self.url = URL(string: supabaseURLString)!
        self.apiKey = supabaseKey
    }

    /// Load .env file from various possible locations
    private static func loadEnvFile() -> [String: String] {
        var env: [String: String] = [:]

        // Possible locations for .env file
        let possiblePaths: [String] = [
            // 1. Bundled with app in Resources folder
            Bundle.main.resourceURL?.appendingPathComponent(".env").path,
            // 2. Next to executable
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(".env").path,
            // 3. Project root (dev mode)
            FileManager.default.currentDirectoryPath + "/.env",
            // 4. Parent directory
            FileManager.default.currentDirectoryPath + "/../.env"
        ].compactMap { $0 }

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path),
               let contents = try? String(contentsOfFile: path, encoding: .utf8) {
                env = parseEnv(contents)
                print("Loaded .env from: \(path)")
                break
            }
        }

        return env
    }

    /// Parse .env file contents into dictionary
    private static func parseEnv(_ contents: String) -> [String: String] {
        var env: [String: String] = [:]

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comments and empty lines
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            // Parse KEY=value
            if let equalIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
                env[key] = value
            }
        }

        return env
    }

    /// Supabase PostgREST expects both `apikey` and `Authorization: Bearer <same key>` for the anon (or service) key.
    private func applySupabaseAuth(to request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }

    private static func parseInt64(_ value: Any?) -> Int64? {
        guard let value else { return nil }
        if let n = value as? NSNumber { return n.int64Value }
        if let i = value as? Int { return Int64(i) }
        return nil
    }

    private static func describeRestFailure(status: Int, body: Data) -> String {
        let snippet = String(data: body, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(400)
        let detail = snippet.map { String($0) } ?? "(empty body)"
        return "HTTP \(status): \(detail)"
    }

    /// Verifies REST connectivity with the anon key (no Supabase Auth user required).
    func initialize() async throws {
        var components = URLComponents(url: url.appendingPathComponent("/rest/v1/batches"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let pingURL = components.url else {
            throw BatchStoreError.supabaseError("Invalid Supabase URL")
        }

        var request = URLRequest(url: pingURL)
        applySupabaseAuth(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw BatchStoreError.supabaseError("No HTTP response from Supabase")
        }

        guard (200...299).contains(http.statusCode) else {
            throw BatchStoreError.supabaseError(
                "Supabase REST \(Self.describeRestFailure(status: http.statusCode, body: data)). Check SUPABASE_URL, SUPABASE_ANON_KEY, and that the `batches` table exists."
            )
        }
    }

    /// All words in the batch are saved with the same `topicId` (chosen in the UI).
    func saveBatch(words: [BatchWordInput], paragraph: String, topicId: Int64) async throws -> Int64 {
        guard !words.isEmpty else {
            throw BatchStoreError.validation("Add at least one word before submitting.")
        }
        guard topicId > 0 else {
            throw BatchStoreError.validation("Select a topic before submitting.")
        }

        // Insert batch using REST API directly
        let batchId = try await insertBatch()

        // Insert words
        for word in words {
            try await insertWord(
                batchId: batchId,
                topicId: topicId,
                word: word.word,
                meaning: word.meaning,
                wordType: word.wordType,
                example1: word.example1,
                example2: word.example2
            )
        }

        // Insert paragraph
        try await insertParagraph(batchId: batchId, paragraph: paragraph)

        return batchId
    }

    private func insertBatch() async throws -> Int64 {
        // Let DB default set `created_at`; body `{}` is enough for BIGSERIAL + default column.
        let body = Data("{}".utf8)

        var request = URLRequest(url: url.appendingPathComponent("/rest/v1/batches"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        applySupabaseAuth(to: &request)
        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw BatchStoreError.supabaseError("No HTTP response when inserting batch")
        }

        guard (200...299).contains(http.statusCode) else {
            throw BatchStoreError.supabaseError(
                "Failed to insert batch — \(Self.describeRestFailure(status: http.statusCode, body: responseData))"
            )
        }

        let jsonObject = try? JSONSerialization.jsonObject(with: responseData)
        let firstRow: [String: Any]?
        if let rows = jsonObject as? [[String: Any]] {
            firstRow = rows.first
        } else if let row = jsonObject as? [String: Any] {
            firstRow = row
        } else {
            firstRow = nil
        }

        guard let row = firstRow else {
            throw BatchStoreError.supabaseError("Invalid response from batch insert (not JSON object/array)")
        }

        guard let idValue = row["id"] else {
            throw BatchStoreError.supabaseError("Batch insert response missing `id`")
        }
        let id: Int64
        if let n = idValue as? NSNumber {
            id = n.int64Value
        } else if let i = idValue as? Int {
            id = Int64(i)
        } else {
            throw BatchStoreError.supabaseError("Batch insert `id` has unexpected type")
        }
        return id
    }

    func fetchTopics() async throws -> [TopicRecord] {
        var components = URLComponents(url: url.appendingPathComponent("/rest/v1/topics"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,name"),
            URLQueryItem(name: "order", value: "name.asc")
        ]
        guard let topicURL = components.url else {
            throw BatchStoreError.supabaseError("Invalid topic list URL")
        }

        var request = URLRequest(url: topicURL)
        applySupabaseAuth(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BatchStoreError.supabaseError(
                "Failed to load topics — \(Self.describeRestFailure(status: status, body: data))"
            )
        }

        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return rows.compactMap { row in
            guard let id = Self.parseInt64(row["id"]),
                  let name = row["name"] as? String else {
                return nil
            }
            return TopicRecord(id: id, name: name)
        }
    }

    /// Inserts a topic row; on unique name conflict, returns the existing row’s id.
    func insertTopic(name: String) async throws -> Int64 {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw BatchStoreError.validation("Topic name is empty.")
        }

        let body = try JSONSerialization.data(withJSONObject: ["name": trimmed])

        var request = URLRequest(url: url.appendingPathComponent("/rest/v1/topics"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        applySupabaseAuth(to: &request)
        request.httpBody = body

        let (respBody, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BatchStoreError.supabaseError("No HTTP response when inserting topic")
        }

        if (200...299).contains(http.statusCode) {
            guard let rows = try JSONSerialization.jsonObject(with: respBody) as? [[String: Any]],
                  let first = rows.first,
                  let id = Self.parseInt64(first["id"]) else {
                throw BatchStoreError.supabaseError("Topic insert response missing id")
            }
            return id
        }

        if http.statusCode == 409 {
            return try await topicIdForExactName(trimmed)
        }

        throw BatchStoreError.supabaseError(
            "Failed to create topic — \(Self.describeRestFailure(status: http.statusCode, body: respBody))"
        )
    }

    private func topicIdForExactName(_ name: String) async throws -> Int64 {
        var components = URLComponents(url: url.appendingPathComponent("/rest/v1/topics"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id"),
            URLQueryItem(name: "name", value: "eq.\(name)"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let topicURL = components.url else {
            throw BatchStoreError.supabaseError("Invalid topic lookup URL")
        }

        var request = URLRequest(url: topicURL)
        applySupabaseAuth(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = rows.first,
              let id = Self.parseInt64(first["id"]) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BatchStoreError.supabaseError(
                "Could not resolve topic id after conflict — \(Self.describeRestFailure(status: status, body: data))"
            )
        }
        return id
    }

    private func insertWord(batchId: Int64, topicId: Int64, word: String, meaning: String, wordType: String, example1: String, example2: String) async throws {
        let json: [String: Any] = [
            "batch_id": batchId,
            "topic_id": topicId,
            "word": word,
            "meaning": meaning,
            "word_type": wordType,
            "example_1": example1,
            "example_2": example2
        ]

        let data = try JSONSerialization.data(withJSONObject: json)

        var request = URLRequest(url: url.appendingPathComponent("/rest/v1/words"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applySupabaseAuth(to: &request)
        request.httpBody = data

        let (respBody, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BatchStoreError.supabaseError(
                "Failed to insert word \"\(word)\" — \(Self.describeRestFailure(status: status, body: respBody))"
            )
        }
    }

    private func insertParagraph(batchId: Int64, paragraph: String) async throws {
        let json: [String: Any] = [
            "batch_id": batchId,
            "paragraph": paragraph
        ]

        let data = try JSONSerialization.data(withJSONObject: json)

        var request = URLRequest(url: url.appendingPathComponent("/rest/v1/paragraphs"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applySupabaseAuth(to: &request)
        request.httpBody = data

        let (respBody, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BatchStoreError.supabaseError(
                "Failed to insert paragraph — \(Self.describeRestFailure(status: status, body: respBody))"
            )
        }
    }

    /// Update an existing word row with enriched agent fields.
    func updateWordEnrichment(
        wordId: Int64,
        word: String,
        meaning: String,
        wordType: String,
        example1: String,
        example2: String
    ) async throws {
        let json: [String: Any] = [
            "word": word,
            "meaning": meaning,
            "word_type": wordType,
            "example_1": example1,
            "example_2": example2
        ]

        let data = try JSONSerialization.data(withJSONObject: json)

        var components = URLComponents(url: url.appendingPathComponent("/rest/v1/words"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(wordId)")
        ]

        guard let endpoint = components.url else {
            throw BatchStoreError.supabaseError("Invalid words update URL")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        applySupabaseAuth(to: &request)
        request.httpBody = data

        let (respBody, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BatchStoreError.supabaseError(
                "Failed to update word #\(wordId) — \(Self.describeRestFailure(status: status, body: respBody))"
            )
        }
    }

    /// Load saved batches from Supabase with optional date filtering
    func loadSavedBatches(dateFilter: DateFilter = .all) async throws -> [SavedBatch] {
        let calendar = Calendar.current
        let now = Date()

        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "select", value: "id,created_at,words(id,word,word_type,meaning,example_1,example_2,topic_id,topics(name)),paragraphs(paragraph)"))
        queryItems.append(URLQueryItem(name: "order", value: "id.desc"))

        switch dateFilter {
        case .all:
            break
        case .week:
            if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) {
                let dateStr = ISO8601DateFormatter().string(from: weekAgo)
                queryItems.append(URLQueryItem(name: "created_at", value: "gte.\(dateStr)"))
            }
        case .month:
            if let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) {
                let dateStr = ISO8601DateFormatter().string(from: monthAgo)
                queryItems.append(URLQueryItem(name: "created_at", value: "gte.\(dateStr)"))
            }
        }

        var components = URLComponents(url: url.appendingPathComponent("/rest/v1/batches"), resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        applySupabaseAuth(to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BatchStoreError.supabaseError(
                "Failed to load batches — \(Self.describeRestFailure(status: status, body: data))"
            )
        }

        guard let batches = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return parseBatches(from: batches)
    }

    /// Parse Supabase response into SavedBatch models
    private func parseBatches(from batches: [[String: Any]]) -> [SavedBatch] {
        return batches.compactMap { batch in
            guard let id = batch["id"] as? Int,
                  let createdAt = batch["created_at"] as? String else {
                return nil
            }

            // Parse words
            var words: [SavedBatchWord] = []
            if let wordsData = batch["words"] as? [[String: Any]] {
                words = wordsData.compactMap { wordData in
                    guard let wordId = wordData["id"] as? Int,
                          let word = wordData["word"] as? String,
                          let meaning = wordData["meaning"] as? String else {
                        return nil
                    }
                    guard let topicId = Self.parseInt64(wordData["topic_id"]) else {
                        return nil
                    }
                    let topicName: String?
                    if let embedded = wordData["topics"] as? [String: Any] {
                        topicName = embedded["name"] as? String
                    } else {
                        topicName = nil
                    }
                    return SavedBatchWord(
                        id: Int64(wordId),
                        word: word,
                        meaning: meaning,
                        wordType: wordData["word_type"] as? String ?? "",
                        example1: wordData["example_1"] as? String ?? "",
                        example2: wordData["example_2"] as? String ?? "",
                        topicId: topicId,
                        topicName: topicName
                    )
                }
            }

            // Parse paragraph
            var paragraph = ""
            if let paragraphs = batch["paragraphs"] as? [[String: Any]],
               let firstPara = paragraphs.first,
               let paraText = firstPara["paragraph"] as? String {
                paragraph = paraText
            }

            return SavedBatch(
                id: Int64(id),
                createdAt: createdAt,
                words: words,
                paragraph: paragraph
            )
        }
    }
}
