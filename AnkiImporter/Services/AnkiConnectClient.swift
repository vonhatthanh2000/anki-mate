import Foundation

/// Posts notes to [AnkiConnect](https://foosoft.net/projects/anki-connect/) on `http://127.0.0.1:8765`.
/// Field names must match your note type in Anki exactly (same as the old `anki.py` script).
enum AnkiConnectClient {
    /// Change these to match your Anki deck and note type (Tools → Manage note types).
    static let defaultDeckName = "Vocab"
    static let defaultModelName = "Basic"

    private static let connectURL = URL(string: "http://127.0.0.1:8765")!
    private static let apiVersion = 6

    enum AnkiConnectError: LocalizedError {
        case invalidResponse
        case httpStatus(Int)
        case ankiError(String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from AnkiConnect."
            case .httpStatus(let code):
                return "AnkiConnect HTTP error (\(code)). Is Anki running with the add-on?"
            case .ankiError(let message):
                return message
            }
        }
    }

    /// Adds one note. Returns Anki’s note id when present.
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
        let body = AddNotePayload(
            action: "addNote",
            version: apiVersion,
            params: AddNotePayload.Params(
                note: AddNotePayload.Note(
                    deckName: deckName,
                    modelName: modelName,
                    fields: AddNotePayload.Fields(
                        word: word,
                        meaning: meaning,
                        wordType: wordType,
                        example1: example1,
                        example2: example2
                    ),
                    tags: tags
                )
            )
        )

        var request = URLRequest(url: connectURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AnkiConnectError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw AnkiConnectError.httpStatus(http.statusCode)
        }

        guard
            let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw AnkiConnectError.invalidResponse
        }

        if let err = obj["error"] as? String, !err.isEmpty {
            throw AnkiConnectError.ankiError(err)
        }

        if let result = obj["result"] {
            if result is NSNull {
                return nil
            }
            if let id = result as? Int {
                return id
            }
            if let id = result as? Int64 {
                return Int(id)
            }
        }
        return nil
    }
}

private struct AddNotePayload: Encodable {
    var action: String
    var version: Int
    var params: Params

    struct Params: Encodable {
        var note: Note
    }

    struct Note: Encodable {
        var deckName: String
        var modelName: String
        var fields: Fields
        var tags: [String]
    }

    struct Fields: Encodable {
        var word: String
        var meaning: String
        var wordType: String
        var example1: String
        var example2: String

        enum CodingKeys: String, CodingKey {
            case word = "Word"
            case meaning = "Meaning"
            case wordType = "Word type"
            case example1 = "Example 1"
            case example2 = "Example 2"
        }
    }
}
