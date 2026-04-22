import Foundation
import AppKit

/// Posts notes to [AnkiConnect](https://foosoft.net/projects/anki-connect/) on `http://127.0.0.1:8765`.
/// Field names must match your note type in Anki exactly (same as the old `anki.py` script).
enum AnkiConnectClient {
    /// Change these to match your Anki deck and note type (Tools → Manage note types).
    static let defaultDeckName = "Vocab"
    static let defaultModelName = "Basic"

    private static let connectURL = URL(string: "http://127.0.0.1:8765")!
    private static let apiVersion = 6
    private static let ankiBundleIDs = [
        "net.ankiweb.dtop",         // Anki 2.1.x
        "org.qt-project.Qt.QtWebEngine",
        "com.anki.drive",           // Alternative
    ]

    enum AnkiConnectError: LocalizedError {
        case invalidResponse
        case httpStatus(Int)
        case ankiError(String)
        case ankiNotFound

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from AnkiConnect."
            case .httpStatus(let code):
                return "AnkiConnect HTTP error (\(code)). Is Anki running with the add-on?"
            case .ankiError(let message):
                return message
            case .ankiNotFound:
                return "Anki application not found. Please install Anki."
            }
        }
    }

    /// Finds Anki application URL by checking multiple methods.
    private static func findAnkiURL() -> URL? {
        // Try bundle identifiers
        for bundleID in ankiBundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                print("Found Anki with bundle ID: \(bundleID)")
                return url
            }
        }

        // Try searching in common locations
        let commonPaths = [
            "/Applications/Anki.app",
            "~/Applications/Anki.app",
            "/Users/*/Applications/Anki.app",
            "/opt/homebrew/Caskroom/anki/*/Anki.app",
            "/usr/local/Caskroom/anki/*/Anki.app",
        ]

        for path in commonPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                print("Found Anki at: \(url.path)")
                return url
            }
        }

        // Try to find by file type association
        let fileManager = FileManager.default
        let domains: [FileManager.SearchPathDomainMask] = [.systemDomainMask, .localDomainMask, .userDomainMask]

        for domain in domains {
            let appDirs = fileManager.urls(for: .applicationDirectory, in: domain)
            for appDir in appDirs {
                let ankiURL = appDir.appendingPathComponent("Anki.app")
                if fileManager.fileExists(atPath: ankiURL.path) {
                    print("Found Anki in app directory: \(ankiURL.path)")
                    return ankiURL
                }
            }
        }

        return nil
    }

    /// Checks if Anki is running by checking running applications.
    private static func isAnkiRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications

        // Check by bundle ID
        for app in runningApps {
            if let bundleID = app.bundleIdentifier {
                if ankiBundleIDs.contains(bundleID) {
                    print("Anki is running with bundle ID: \(bundleID)")
                    return true
                }
            }
        }

        // Check by name (fallback)
        for app in runningApps {
            let name = app.localizedName?.lowercased() ?? ""
            if name.contains("anki") {
                print("Anki is running (detected by name): \(app.localizedName ?? "Unknown")")
                return true
            }
        }

        return false
    }

    /// Opens Anki application using 'open -a' command.
    /// Does not check if already running - just executes the command.
    static func openAnki() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "/Applications/Anki.app"]

        do {
            try process.run()
            print("Executed: open -a /Applications/Anki.app")
        } catch {
            print("Failed to open Anki: \(error)")
        }
    }

    /// Quick ping to check if AnkiConnect is responding.
    private static func pingAnkiConnect() async -> Bool {
        let pingBody: [String: Any] = ["action": "version", "version": apiVersion]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: pingBody) else {
            return false
        }

        var request = URLRequest(url: connectURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 2
        request.httpBody = jsonData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
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
