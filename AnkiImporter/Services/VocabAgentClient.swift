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
        let result: PythonProcessResult
        do {
            result = try await PythonAgentRuntime.run(
                scriptName: "vocab_cli.py",
                arguments: [word, meaning]
            )
        } catch PythonAgentRuntime.RuntimeError.scriptNotFound(_) {
            throw AgentError.scriptNotFound
        }

        if result.terminationStatus != 0 {
            let errorMessage = String(data: result.errorOutput, encoding: .utf8) ?? "Unknown error"
            throw AgentError.executionFailed(errorMessage)
        }

        guard let outputString = String(data: result.output, encoding: .utf8),
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
}
