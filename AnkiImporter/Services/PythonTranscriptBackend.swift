import Foundation
import TranscriptInsightCore

enum PythonTranscriptBackend {
    static let live = TranscriptAcquisitionClient(
        acquireWithProgress: { url, progress in
            try await request(mode: "transcribe", url: url, onProgress: progress)
        }
    )

    private static func request(
        mode: String,
        url: URL,
        onProgress: @escaping @Sendable (TranscriptAcquisitionProgress) async -> Void = { _ in }
    ) async throws -> Transcript {
        guard let scriptPath = findScriptPath() else {
            throw TranscriptBackendFailure(
                kind: "backend_unavailable",
                message: "The transcript backend is missing. Reinstall Anki Mate and try again."
            )
        }

        let python = findPythonPath(forScript: scriptPath)
        let output: ProcessOutput
        do {
            let defaultTimeout = mode == "captions" ? 45.0 : 180.0
            let configuredTimeout = ProcessInfo.processInfo.environment["TRANSCRIPT_PROCESS_TIMEOUT_SECONDS"]
                .flatMap(Double.init)
            output = try await runProcess(
                executable: python,
                arguments: [scriptPath, mode, url.absoluteString],
                timeout: configuredTimeout ?? defaultTimeout,
                onProgress: onProgress
            )
        } catch let failure as TranscriptBackendFailure {
            throw failure
        } catch is CancellationError {
            throw CancellationError()
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

    private static func runProcess(
        executable: String,
        arguments: [String],
        timeout: TimeInterval,
        onProgress: @escaping @Sendable (TranscriptAcquisitionProgress) async -> Void
    ) async throws -> ProcessOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        let stdoutCollector = DataCollector()
        let stderrCollector = ProgressCollector()
        let (progressStream, progressContinuation) = AsyncStream.makeStream(
            of: TranscriptAcquisitionProgress.self
        )

        stdout.fileHandleForReading.readabilityHandler = { handle in
            stdoutCollector.append(handle.availableData)
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            for stage in stderrCollector.append(handle.availableData) {
                progressContinuation.yield(stage)
            }
        }
        process.standardOutput = stdout
        process.standardError = stderr

        let managedProcess = ManagedProcess(process)
        let progressTask = Task {
            for await stage in progressStream {
                await onProgress(stage)
            }
        }

        do {
            try process.run()
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
            stderr.fileHandleForReading.readabilityHandler = nil
            progressContinuation.finish()
            await progressTask.value
            throw error
        }

        let waitTask = Task.detached(priority: .userInitiated) {
            managedProcess.waitUntilExit()
        }
        let timeoutTask = Task.detached {
            try? await Task.sleep(nanoseconds: UInt64(max(timeout, 1) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            managedProcess.terminate(timedOut: true)
        }

        await withTaskCancellationHandler {
            await waitTask.value
        } onCancel: {
            managedProcess.terminate(timedOut: false)
        }
        timeoutTask.cancel()

        stdout.fileHandleForReading.readabilityHandler = nil
        stderr.fileHandleForReading.readabilityHandler = nil
        stdoutCollector.append(stdout.fileHandleForReading.readDataToEndOfFile())
        for stage in stderrCollector.append(stderr.fileHandleForReading.readDataToEndOfFile()) {
            progressContinuation.yield(stage)
        }
        for stage in stderrCollector.finish() {
            progressContinuation.yield(stage)
        }
        progressContinuation.finish()
        await progressTask.value

        if Task.isCancelled {
            throw CancellationError()
        }
        if managedProcess.didTimeOut {
            throw TranscriptBackendFailure(
                kind: "transcription_timeout",
                message: "Transcription took too long. Try a shorter video or try again."
            )
        }

        return ProcessOutput(
            status: managedProcess.terminationStatus,
            stdout: stdoutCollector.data,
            stderr: stderrCollector.data
        )
    }
}

private final class ManagedProcess: @unchecked Sendable {
    private let process: Process
    private let lock = NSLock()
    private var timedOut = false

    init(_ process: Process) {
        self.process = process
    }

    func waitUntilExit() {
        process.waitUntilExit()
    }

    func terminate(timedOut: Bool) {
        lock.lock()
        if timedOut { self.timedOut = true }
        let isRunning = process.isRunning
        lock.unlock()
        if isRunning { process.terminate() }
    }

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    var terminationStatus: Int32 {
        process.terminationStatus
    }
}

private final class DataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ value: Data) {
        guard !value.isEmpty else { return }
        lock.lock()
        storage.append(value)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private final class ProgressCollector: @unchecked Sendable {
    private static let prefix = "ANKI_MATE_PROGRESS:"
    private let lock = NSLock()
    private var rawData = Data()
    private var pending = ""

    func append(_ value: Data) -> [TranscriptAcquisitionProgress] {
        guard !value.isEmpty else { return [] }
        lock.lock()
        defer { lock.unlock() }
        rawData.append(value)
        pending += String(decoding: value, as: UTF8.self)
        return consumeCompleteLines()
    }

    func finish() -> [TranscriptAcquisitionProgress] {
        lock.lock()
        defer { lock.unlock() }
        guard !pending.isEmpty else { return [] }
        let final = parse(pending)
        pending = ""
        return final.map { [$0] } ?? []
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return rawData
    }

    private func consumeCompleteLines() -> [TranscriptAcquisitionProgress] {
        var stages: [TranscriptAcquisitionProgress] = []
        while let boundary = pending.firstIndex(where: { $0 == "\n" || $0 == "\r" }) {
            let line = String(pending[..<boundary])
            pending.removeSubrange(...boundary)
            if let stage = parse(line) { stages.append(stage) }
        }
        return stages
    }

    private func parse(_ line: String) -> TranscriptAcquisitionProgress? {
        guard let prefixRange = line.range(of: Self.prefix) else { return nil }
        let payload = String(line[prefixRange.upperBound...])
        guard let data = payload.data(using: .utf8),
              let event = try? JSONDecoder().decode(ProgressEvent.self, from: data)
        else { return nil }
        return TranscriptAcquisitionProgress(rawValue: event.stage)
    }
}

private struct ProcessOutput: Sendable {
    let status: Int32
    let stdout: Data
    let stderr: Data
}

private struct ProgressEvent: Decodable {
    let stage: String
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
