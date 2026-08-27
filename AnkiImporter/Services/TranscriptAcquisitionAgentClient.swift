import Foundation

@MainActor
protocol TranscriptAcquiring {
    func acquireCaptions(source: VideoSource) async throws -> TranscriptAcquisition?
    func transcribe(source: VideoSource) async throws -> TranscriptAcquisition
    func transcribe(localFile: URL, source: VideoSource?) async throws -> TranscriptAcquisition
}

enum TranscriptAcquisitionStage: String, Codable, Equatable, Sendable {
    case acquisition
    case transcription
    case configuration
}

struct TranscriptAcquisitionFailure: LocalizedError, Equatable, Codable, Sendable {
    let stage: TranscriptAcquisitionStage
    let message: String
    let retryable: Bool

    var errorDescription: String? {
        let prefix: String
        switch stage {
        case .acquisition: prefix = "Video acquisition failed"
        case .transcription: prefix = "Speech-to-text failed"
        case .configuration: prefix = "Transcript acquisition is not configured"
        }
        return "\(prefix): \(message)"
    }
}

@MainActor
struct TranscriptAcquisitionAgentClient: TranscriptAcquiring {
    private struct Command: Encodable {
        let action: String
        let source: VideoSource?
        let localFilePath: String?
    }

    private struct CaptionLookupResult: Decodable {
        let acquisition: TranscriptAcquisition?
    }

    func acquireCaptions(source: VideoSource) async throws -> TranscriptAcquisition? {
        let result = try await run(Command(action: "lookup_captions", source: source, localFilePath: nil))
        return try Self.decodeCaptionLookup(result)
    }

    nonisolated static func decodeCaptionLookup(
        _ result: PythonProcessResult
    ) throws -> TranscriptAcquisition? {
        try decode(
            result,
            as: CaptionLookupResult.self,
            malformedStage: .acquisition
        ).acquisition
    }

    func transcribe(source: VideoSource) async throws -> TranscriptAcquisition {
        try await execute(Command(action: "transcribe_url", source: source, localFilePath: nil))
    }

    func transcribe(localFile: URL, source: VideoSource?) async throws -> TranscriptAcquisition {
        try await execute(
            Command(action: "transcribe_file", source: source, localFilePath: localFile.path)
        )
    }

    private func execute(_ command: Command) async throws -> TranscriptAcquisition {
        try Self.decode(try await run(command))
    }

    private func run(_ command: Command) async throws -> PythonProcessResult {
        do {
            return try await PythonAgentRuntime.run(
            scriptName: "transcript_acquisition_cli.py",
            standardInput: try JSONEncoder().encode(command),
            timeoutSeconds: 360
            )
        } catch PythonAgentRuntime.RuntimeError.timedOut {
            let stage: TranscriptAcquisitionStage = command.action == "lookup_captions"
                ? .acquisition
                : .transcription
            throw TranscriptAcquisitionFailure(
                stage: stage,
                message: "The local operation timed out. You can retry or use a fallback.",
                retryable: true
            )
        }
    }

    nonisolated static func decode(_ result: PythonProcessResult) throws -> TranscriptAcquisition {
        try decode(result, as: TranscriptAcquisition.self, malformedStage: .transcription)
    }

    nonisolated private static func decode<Response: Decodable>(
        _ result: PythonProcessResult,
        as responseType: Response.Type,
        malformedStage: TranscriptAcquisitionStage
    ) throws -> Response {
        guard result.terminationStatus == 0 else {
            if let failure = try? JSONDecoder().decode(
                TranscriptAcquisitionFailure.self,
                from: result.errorOutput
            ) {
                throw failure
            }
            let sanitized = String(data: result.errorOutput, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw TranscriptAcquisitionFailure(
                stage: .acquisition,
                message: sanitized.flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown local agent error.",
                retryable: true
            )
        }
        do {
            return try JSONDecoder().decode(Response.self, from: result.output)
        } catch {
            throw TranscriptAcquisitionFailure(
                stage: malformedStage,
                message: "The local agent returned malformed transcript data. Try again or paste the transcript manually.",
                retryable: true
            )
        }
    }
}
