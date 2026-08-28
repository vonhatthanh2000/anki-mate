import Foundation

struct PythonProcessResult: Sendable {
    let output: Data
    let errorOutput: Data
    let terminationStatus: Int32
}

enum PythonAgentRuntime {
    enum RuntimeError: LocalizedError {
        case scriptNotFound(String)
        case timedOut

        var errorDescription: String? {
            switch self {
            case .scriptNotFound(let name):
                return "Python agent script not found: \(name)."
            case .timedOut:
                return "The Python agent timed out."
            }
        }
    }

    static func run(
        scriptName: String,
        arguments: [String] = [],
        standardInput: Data? = nil,
        timeoutSeconds: TimeInterval? = nil
    ) async throws -> PythonProcessResult {
        guard let scriptPath = findScriptPath(named: scriptName) else {
            throw RuntimeError.scriptNotFound(scriptName)
        }
        let pythonPath = findPythonPath(forScript: scriptPath)

        let holder = PythonProcessHolder()
        return try await withTaskCancellationHandler {
            let result = try await Task.detached(priority: .userInitiated) {
            let process = Process()
            holder.set(process)
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [scriptPath] + arguments
            process.currentDirectoryURL = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            var inputPipe: Pipe?
            if standardInput != nil {
                let pipe = Pipe()
                inputPipe = pipe
                process.standardInput = pipe
            }

            try holder.run(process)
            let timeoutWorkItem = DispatchWorkItem { holder.timeout() }
            if let timeoutSeconds {
                DispatchQueue.global(qos: .userInitiated).asyncAfter(
                    deadline: .now() + timeoutSeconds,
                    execute: timeoutWorkItem
                )
            }

            if let standardInput, let inputPipe {
                inputPipe.fileHandleForWriting.write(standardInput)
                try? inputPipe.fileHandleForWriting.close()
            }

            let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            timeoutWorkItem.cancel()

            if holder.didTimeOut {
                throw RuntimeError.timedOut
            }

            return PythonProcessResult(
                output: output,
                errorOutput: errorOutput,
                terminationStatus: process.terminationStatus
            )
            }.value
            if holder.wasCancelled {
                throw CancellationError()
            }
            return result
        } onCancel: {
            holder.cancel()
        }
    }

    private static func findScriptPath(named scriptName: String) -> String? {
        var candidates: [URL] = []

        if let resourcesURL = Bundle.main.resourceURL {
            candidates.append(resourcesURL.appendingPathComponent("agent/\(scriptName)"))
        }

        if let executableURL = Bundle.main.executableURL {
            let executableDirectory = executableURL.deletingLastPathComponent()
            candidates.append(executableDirectory.appendingPathComponent("agent/\(scriptName)"))
            candidates.append(
                executableDirectory
                    .deletingLastPathComponent()
                    .appendingPathComponent("agent/\(scriptName)")
            )
        }

        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        candidates.append(workingDirectory.appendingPathComponent("agent/\(scriptName)"))
        candidates.append(workingDirectory.appendingPathComponent("../agent/\(scriptName)"))

        return candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) })?.path
    }

    private static func findPythonPath(forScript scriptPath: String) -> String {
        let scriptDirectory = URL(fileURLWithPath: scriptPath).deletingLastPathComponent()
        let localVirtualEnvironment = scriptDirectory.appendingPathComponent(".venv/bin/python3").path
        if FileManager.default.fileExists(atPath: localVirtualEnvironment) {
            return localVirtualEnvironment
        }

        if let resourcesURL = Bundle.main.resourceURL {
            let bundledPython = resourcesURL.appendingPathComponent("agent/.venv/bin/python3").path
            if FileManager.default.fileExists(atPath: bundledPython) {
                return bundledPython
            }
        }

        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "python3"
    }
}

private final class PythonProcessHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false
    private var timedOut = false

    var wasCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func set(_ process: Process) {
        lock.lock()
        self.process = process
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel, process.isRunning {
            process.terminate()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let process = process
        lock.unlock()
        if let process, process.isRunning {
            process.terminate()
        }
    }

    func run(_ process: Process) throws {
        lock.lock()
        defer { lock.unlock() }
        if cancelled {
            throw CancellationError()
        }
        try process.run()
    }

    func timeout() {
        lock.lock()
        guard let process, process.isRunning else {
            lock.unlock()
            return
        }
        timedOut = true
        lock.unlock()
        process.terminate()
    }
}
