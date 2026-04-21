import Foundation

/// Response structure from Python vocabulary agent.
struct VocabAgentResponse: Codable {
    let word: String
    let meaning: String
    let wordType: String
    let example1: String
    let example2: String
    let error: String?
    let rawResponse: String?
}

/// Calls the Python vocabulary agent to enrich word data.
enum VocabAgentClient {
    enum AgentError: LocalizedError {
        case scriptNotFound
        case executionFailed(String)
        case invalidOutput
        case pythonError(String)

        var errorDescription: String? {
            switch self {
            case .scriptNotFound:
                return "Python agent script not found."
            case .executionFailed(let message):
                return "Failed to run agent: \(message)"
            case .invalidOutput:
                return "Agent returned invalid data."
            case .pythonError(let message):
                return "Python error: \(message)"
            }
        }
    }

    /// Enriches a word with type and examples by calling the Python agent.
    static func enrichWord(word: String, meaning: String) async throws -> VocabAgentResponse {
        let scriptPath = findScriptPath()

        guard let scriptPath = scriptPath else {
            throw AgentError.scriptNotFound
        }

        // Find Python executable (prefer venv Python next to script)
        let pythonPath = findPythonPath(forScript: scriptPath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [scriptPath, word, meaning]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AgentError.executionFailed(errorMessage)
        }

        guard let outputString = String(data: outputData, encoding: .utf8),
              !outputString.isEmpty else {
            throw AgentError.invalidOutput
        }

        // Parse JSON response
        guard let jsonData = outputString.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            throw AgentError.invalidOutput
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(VocabAgentResponse.self, from: jsonData)

        if let error = response.error {
            throw AgentError.pythonError(error)
        }

        return response
    }

    private static func findScriptPath() -> String? {
        // First: Try inside app bundle Resources (for packaged app)
        if let resourcesURL = Bundle.main.resourceURL {
            let bundledScript = resourcesURL.appendingPathComponent("agent/vocab_cli.py").path
            if FileManager.default.fileExists(atPath: bundledScript) {
                print("Using bundled agent: \(bundledScript)")
                return bundledScript
            }
        }

        // Second: Try next to executable (for dev builds)
        if let executableURL = Bundle.main.executableURL {
            let executableDir = executableURL.deletingLastPathComponent()

            let scriptPath = executableDir.appendingPathComponent("agent/vocab_cli.py").path
            if FileManager.default.fileExists(atPath: scriptPath) {
                print("Using dev agent: \(scriptPath)")
                return scriptPath
            }

            // Try one level up
            let parentDir = executableDir.deletingLastPathComponent()
            let scriptPath2 = parentDir.appendingPathComponent("agent/vocab_cli.py").path
            if FileManager.default.fileExists(atPath: scriptPath2) {
                print("Using dev agent: \(scriptPath2)")
                return scriptPath2
            }
        }

        // Fallback to hardcoded paths
        let possiblePaths = [
            "/Users/justee_vo/personal/anki-mate/agent/vocab_cli.py",
            "./agent/vocab_cli.py",
            "../agent/vocab_cli.py",
        ]

        for path in possiblePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expandedPath) {
                print("Using fallback agent: \(expandedPath)")
                return expandedPath
            }
        }

        print("Could not find vocab_cli.py")
        return nil
    }

    private static func findPythonPath(forScript scriptPath: String) -> String {
        // First, try to find venv Python relative to the script
        let scriptDir = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()
        let venvPython = scriptDir.appendingPathComponent(".venv/bin/python3").path

        if FileManager.default.fileExists(atPath: venvPython) {
            print("Using venv Python: \(venvPython)")
            return venvPython
        }

        // Try bundled venv in Resources (for packaged app)
        if let resourcesURL = Bundle.main.resourceURL {
            let bundledVenv = resourcesURL.appendingPathComponent("agent/.venv/bin/python3").path
            if FileManager.default.fileExists(atPath: bundledVenv) {
                print("Using bundled venv Python: \(bundledVenv)")
                return bundledVenv
            }
        }

        // Fallback to system Python
        let possiblePaths = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "python3",
            "python",
        ]

        for path in possiblePaths {
            if path == "python3" || path == "python" {
                return path
            }
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return "python3" // Default fallback
    }
}
