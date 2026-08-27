import Foundation
import Testing
@testable import AnkiImporter

@MainActor
@Suite
struct AnkiConnectClientTests {
    @Test
    func genericWriterChecksModelAndFieldsCreatesDeckAndParsesNoteID() async throws {
        var actions: [String] = []
        var addedFields: [String: String] = [:]
        MockAnkiURLProtocol.handler = { request in
            let body = try #require(request.httpBody)
            let payload = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let action = try #require(payload["action"] as? String)
            actions.append(action)
            let result: Any
            switch action {
            case "version": result = 6
            case "modelNames": result = ["Natural English"]
            case "modelFieldNames": result = [
                "Expression or pattern", "Category", "Meaning and usage",
                "Original transcript example", "New natural example", "CEFR estimate", "Source URL",
            ]
            case "findNotes": result = []
            case "createDeck": result = 44
            case "addNote":
                let params = try #require(payload["params"] as? [String: Any])
                let note = try #require(params["note"] as? [String: Any])
                addedFields = try #require(note["fields"] as? [String: String])
                result = 9_876_543_210 as Int64
            default: Issue.record("Unexpected action: \(action)"); result = NSNull()
            }
            return Self.response(for: request, result: result)
        }
        let client = AnkiConnectClient(session: mockSession())
        let note = AnkiNote(
            deckName: "Natural English",
            modelName: "Natural English",
            fields: [
                "Expression or pattern": "rock & roll <3",
                "Category": "Collocation",
                "Meaning and usage": "line one\nline two",
                "Original transcript example": "She said, “keep going.”",
                "New natural example": "Emoji 🔬 stays intact.",
                "CEFR estimate": "B2",
                "Source URL": "https://youtu.be/example?a=1&b=2",
            ],
            tags: [],
            deduplicationTag: "anki_mate_transcript_42_item_1"
        )

        let identifier = try await client.write(note)

        #expect(identifier == 9_876_543_210)
        #expect(actions == ["version", "modelNames", "modelFieldNames", "findNotes", "createDeck", "addNote"])
        #expect(addedFields == note.fields)
    }

    @Test
    func missingNaturalEnglishSetupProducesActionableErrors() async {
        MockAnkiURLProtocol.handler = { request in
            let payload = try #require(
                JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: Any]
            )
            let action = try #require(payload["action"] as? String)
            let result: Any = action == "version" ? 6 : []
            return Self.response(for: request, result: result)
        }
        let client = AnkiConnectClient(session: mockSession())
        let note = AnkiNote(
            deckName: "Natural English",
            modelName: "Natural English",
            fields: ["Expression or pattern": "follow through"],
            tags: []
        )

        await #expect(throws: AnkiConnectClient.AnkiConnectError.missingModel("Natural English")) {
            try await client.write(note)
        }
    }

    @Test
    func unavailableAnkiConnectIsClearAndRecoverable() async {
        MockAnkiURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        let client = AnkiConnectClient(session: mockSession())
        let note = AnkiNote(deckName: "Vocab", modelName: "Basic", fields: [:], tags: [])

        await #expect(throws: AnkiConnectClient.AnkiConnectError.unavailable) {
            try await client.write(note)
        }
    }

    @Test
    func transportReturnsExistingNoteForTheSameExportTag() async throws {
        var actions: [String] = []
        MockAnkiURLProtocol.handler = { request in
            let payload = try #require(
                JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: Any]
            )
            let action = try #require(payload["action"] as? String)
            actions.append(action)
            let result: Any
            switch action {
            case "version": result = 6
            case "modelNames": result = ["Natural English"]
            case "modelFieldNames": result = ["Expression or pattern"]
            case "findNotes": result = [777]
            default: Issue.record("Duplicate export should not create a deck or note"); result = NSNull()
            }
            return Self.response(for: request, result: result)
        }
        let client = AnkiConnectClient(session: mockSession())
        let note = AnkiNote(
            deckName: "Natural English",
            modelName: "Natural English",
            fields: ["Expression or pattern": "follow through"],
            tags: ["anki_mate_transcript_42_item_1"],
            deduplicationTag: "anki_mate_transcript_42_item_1"
        )

        #expect(try await client.write(note) == 777)
        #expect(actions == ["version", "modelNames", "modelFieldNames", "findNotes"])
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockAnkiURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    nonisolated private static func response(for request: URLRequest, result: Any) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let body = try! JSONSerialization.data(withJSONObject: ["result": result, "error": NSNull()])
        return (response, body)
    }
}

private final class MockAnkiURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
