import Foundation
import TranscriptInsightCore

enum PythonTranscriptBackend {
    static let live = TranscriptAcquisitionClient(
        captions: { url in try await request(mode: "captions", url: url) },
        speechToText: { url in try await request(mode: "transcribe", url: url) }
    )

    private static func request(mode: String, url: URL) async throws -> Transcript {
        guard let scriptPath = findScriptPath() else {
            throw TranscriptBackendFailure(
                kind: "backend_unavailable",
                message: "The transcript backend is missing. Reinstall Anki Mate and try again."
            )
        }

        let python = findPythonPath(forScript: scriptPath)
        let output: ProcessOutput
        do {
            output = try await runProcess(executable: python, arguments: [scriptPath, mode, url.absoluteString])
        } catch {
            throw TranscriptBackendFailure(
                kind: "backend_unavailable",
                message: "The transcript backend could not start. Check the Python setup and try again."
            )
        }

        guard let response = try? JSONDecoder().decode(CLIResponse.self, from: output.stdout) else {
            let diagnostic = String(data: output.stderr, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = diagnostic.flatMap { $0.isEmpty ? nil : "The transcript backend failed: \($0)" }
            throw TranscriptBackendFailure(
                kind: "backend_invalid_response",
                message: message ?? "The transcript backend returned an invalid response."
            )
        }

        if let error = response.error {
            throw TranscriptBackendFailure(kind: error.kind, message: error.message)
        }
        guard
            response.ok,
            let rawSource = response.source,
            let source = TranscriptSource(rawValue: rawSource),
            let sentences = response.sentences,
            !sentences.isEmpty
        else {
            throw TranscriptBackendFailure(
                kind: "backend_invalid_response",
                message: "The transcript backend returned an incomplete transcript."
            )
        }
        return Transcript(source: source, sentences: sentences, cleanupWarning: response.cleanupWarning)
    }

    private static func findScriptPath() -> String? {
        let fileManager = FileManager.default
        var candidates: [URL] = []

        if let resources = Bundle.main.resourceURL {
            candidates.append(resources.appendingPathComponent("agent/transcript_cli.py"))
        }
        if let executable = Bundle.main.executableURL {
            let directory = executable.deletingLastPathComponent()
            candidates.append(directory.appendingPathComponent("agent/transcript_cli.py"))
            candidates.append(directory.deletingLastPathComponent().appendingPathComponent("agent/transcript_cli.py"))
        }
        candidates.append(
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("agent/transcript_cli.py")
        )
        return candidates.first(where: { fileManager.fileExists(atPath: $0.path) })?.path
    }

    private static func findPythonPath(forScript scriptPath: String) -> String {
        let fileManager = FileManager.default
        let scriptDirectory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()
        let candidates = [
            scriptDirectory.appendingPathComponent(".venv/bin/python3").path,
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
        ]
        return candidates.first(where: fileManager.fileExists(atPath:)) ?? "/usr/bin/python3"
    }

    private static func runProcess(executable: String, arguments: [String]) async throws -> ProcessOutput {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr
            try process.run()
            process.waitUntilExit()
            return ProcessOutput(
                status: process.terminationStatus,
                stdout: stdout.fileHandleForReading.readDataToEndOfFile(),
                stderr: stderr.fileHandleForReading.readDataToEndOfFile()
            )
        }.value
    }
}

private struct ProcessOutput: Sendable {
    let status: Int32
    let stdout: Data
    let stderr: Data
}

private struct CLIResponse: Decodable {
    let ok: Bool
    let source: String?
    let sentences: [String]?
    let cleanupWarning: String?
    let error: CLIError?

    enum CodingKeys: String, CodingKey {
        case ok, source, sentences, error
        case cleanupWarning = "cleanup_warning"
    }
}

private struct CLIError: Decodable {
    let kind: String
    let message: String
}
