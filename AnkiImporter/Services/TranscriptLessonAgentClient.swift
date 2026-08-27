import Foundation

@MainActor
struct TranscriptLessonAgentClient: TranscriptLessonAnalyzing {
    enum AgentError: LocalizedError {
        case executionFailed(String)
        case invalidOutput(String)

        var errorDescription: String? {
            switch self {
            case .executionFailed(let message):
                return "Transcript analysis failed: \(message)"
            case .invalidOutput(let message):
                return "Transcript analysis returned invalid data: \(message)"
            }
        }
    }

    private struct AnalyzeCommand: Encodable {
        let action = "analyze"
        let transcript: String
    }

    private struct EvaluateCommand: Encodable {
        let action = "evaluate"
        let request: ExerciseEvaluationRequest
    }

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func analyze(transcript: String) async throws -> TranscriptLessonAnalysis {
        try await execute(
            command: AnalyzeCommand(transcript: transcript),
            responseType: TranscriptLessonAnalysis.self
        )
    }

    func evaluate(_ request: ExerciseEvaluationRequest) async throws -> ExerciseFeedback {
        try await execute(
            command: EvaluateCommand(request: request),
            responseType: ExerciseFeedback.self
        )
    }

    private func execute<Command: Encodable, Response: Decodable>(
        command: Command,
        responseType: Response.Type
    ) async throws -> Response {
        let input = try encoder.encode(command)
        let result = try await PythonAgentRuntime.run(
            scriptName: "transcript_lesson_cli.py",
            standardInput: input
        )

        guard result.terminationStatus == 0 else {
            let message = String(data: result.errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw AgentError.executionFailed(
                message.flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown agent error"
            )
        }

        do {
            return try decoder.decode(Response.self, from: result.output)
        } catch {
            throw AgentError.invalidOutput(error.localizedDescription)
        }
    }
}
