import AppKit
import Foundation

struct AnkiNote: Equatable, Sendable {
    let deckName: String
    let modelName: String
    let fields: [String: String]
    let tags: [String]
    var deduplicationTag: String? = nil
}

@MainActor
protocol AnkiNoteWriting {
    func write(_ note: AnkiNote) async throws -> Int64
}

enum AnkiNoteMapping {
    static func boostVocab(
        deckName: String,
        modelName: String,
        word: String,
        meaning: String,
        wordType: String,
        example1: String,
        example2: String,
        tags: [String]
    ) -> AnkiNote {
        AnkiNote(
            deckName: deckName,
            modelName: modelName,
            fields: [
                "Word": word,
                "Meaning": meaning,
                "Word type": wordType,
                "Example 1": example1,
                "Example 2": example2,
            ],
            tags: tags
        )
    }

    static func naturalEnglish(
        item: TranscriptLanguageItem,
        sourceURL: String?,
        deduplicationTag: String
    ) -> AnkiNote {
        AnkiNote(
            deckName: AnkiConnectClient.naturalEnglishDeckName,
            modelName: AnkiConnectClient.naturalEnglishModelName,
            fields: [
                "Expression or pattern": item.expression,
                "Category": item.primaryCategory.rawValue,
                "Meaning and usage": item.meaningAndUsage,
                "Original transcript example": item.sourceExcerpt,
                "New natural example": item.naturalExample,
                "CEFR estimate": item.cefrEstimate,
                "Source URL": sourceURL ?? "",
            ],
            tags: ["anki-mate", "natural-english", deduplicationTag],
            deduplicationTag: deduplicationTag
        )
    }
}

/// Generic AnkiConnect note writer shared by BoostVocab and Transcript Lessons.
@MainActor
final class AnkiConnectClient: AnkiNoteWriting {
    static let shared = AnkiConnectClient()
    nonisolated static let defaultDeckName = "Vocab"
    nonisolated static let defaultModelName = "Basic"
    nonisolated static let naturalEnglishDeckName = "Natural English"
    nonisolated static let naturalEnglishModelName = "Natural English"

    enum AnkiConnectError: LocalizedError, Equatable {
        case unavailable
        case invalidResponse
        case httpStatus(Int)
        case ankiError(String)
        case missingModel(String)
        case missingFields(model: String, fields: [String])
        case noteIdentifierMissing

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "AnkiConnect is unavailable. Open Anki, install and enable the AnkiConnect add-on, then try again."
            case .invalidResponse:
                return "AnkiConnect returned an invalid response. Restart Anki and try again."
            case .httpStatus(let code):
                return "AnkiConnect returned HTTP \(code). Make sure Anki and the AnkiConnect add-on are running."
            case .ankiError(let message):
                return "AnkiConnect: \(message)"
            case .missingModel(let model):
                return "Create an Anki note type named “\(model)” with the required Natural English fields, then try again."
            case .missingFields(let model, let fields):
                return "The “\(model)” note type is missing these fields: \(fields.joined(separator: ", ")). Add them in Anki → Tools → Manage Note Types."
            case .noteIdentifierMissing:
                return "Anki added no note identifier, so the export could not be recorded safely."
            }
        }
    }

    private let endpoint: URL
    private let session: URLSession
    private let apiVersion = 6

    init(
        endpoint: URL = URL(string: "http://127.0.0.1:8765")!,
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint
        self.session = session
    }

    func write(_ note: AnkiNote) async throws -> Int64 {
        _ = try await invoke(action: "version")

        let modelNames = try await invoke(action: "modelNames")
        guard let names = modelNames as? [String], names.contains(note.modelName) else {
            throw AnkiConnectError.missingModel(note.modelName)
        }

        let modelFields = try await invoke(
            action: "modelFieldNames",
            params: ["modelName": note.modelName]
        )
        guard let availableFields = modelFields as? [String] else {
            throw AnkiConnectError.invalidResponse
        }
        let missingFields = note.fields.keys.filter { !availableFields.contains($0) }.sorted()
        guard missingFields.isEmpty else {
            throw AnkiConnectError.missingFields(model: note.modelName, fields: missingFields)
        }

        if let tag = note.deduplicationTag {
            let matches = try await invoke(action: "findNotes", params: ["query": "tag:\(tag)"])
            if let identifiers = matches as? [NSNumber], let existing = identifiers.first {
                return existing.int64Value
            }
        }

        _ = try await invoke(action: "createDeck", params: ["deck": note.deckName])
        let result = try await invoke(
            action: "addNote",
            params: [
                "note": [
                    "deckName": note.deckName,
                    "modelName": note.modelName,
                    "fields": note.fields,
                    "tags": note.tags,
                ] as [String: Any]
            ]
        )
        if let identifier = result as? NSNumber {
            return identifier.int64Value
        }
        throw AnkiConnectError.noteIdentifierMissing
    }

    static func addNote(
        deckName: String = defaultDeckName,
        modelName: String = defaultModelName,
        word: String,
        meaning: String,
        wordType: String,
        example1: String,
        example2: String,
        tags: [String] = []
    ) async throws -> Int? {
        let note = AnkiNoteMapping.boostVocab(
            deckName: deckName,
            modelName: modelName,
            word: word,
            meaning: meaning,
            wordType: wordType,
            example1: example1,
            example2: example2,
            tags: tags
        )
        return Int(try await shared.write(note))
    }

    static func openAnki() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "/Applications/Anki.app"]
        try? process.run()
    }

    private func invoke(action: String, params: [String: Any]? = nil) async throws -> Any {
        var payload: [String: Any] = ["action": action, "version": apiVersion]
        if let params { payload["params"] = params }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AnkiConnectError.unavailable
        }
        guard let http = response as? HTTPURLResponse else {
            throw AnkiConnectError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw AnkiConnectError.httpStatus(http.statusCode)
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object.keys.contains("result"), object.keys.contains("error") else {
            throw AnkiConnectError.invalidResponse
        }
        if let error = object["error"] as? String, !error.isEmpty {
            throw AnkiConnectError.ankiError(error)
        }
        return object["result"] ?? NSNull()
    }
}
