import Foundation

struct PythonProcessResult: Sendable {
    let output: Data
    let errorOutput: Data
    let terminationStatus: Int32
}

enum PythonAgentRuntime {
    enum RuntimeError: LocalizedError {
        case scriptNotFound(String)

        var errorDescription: String? {
            switch self {
            case .scriptNotFound(let name):
                return "Python agent script not found: \(name)."
            }
        }
    }

    static func run(
        scriptName: String,
        arguments: [String] = [],
        standardInput: Data? = nil
    ) async throws -> PythonProcessResult {
        guard let scriptPath = findScriptPath(named: scriptName) else {
            throw RuntimeError.scriptNotFound(scriptName)
        }
        let pythonPath = findPythonPath(forScript: scriptPath)

        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: pythonPath)
            process.arguments = [scriptPath] + arguments

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

            try process.run()

            if let standardInput, let inputPipe {
                inputPipe.fileHandleForWriting.write(standardInput)
                try? inputPipe.fileHandleForWriting.close()
            }

            let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            return PythonProcessResult(
                output: output,
                errorOutput: errorOutput,
                terminationStatus: process.terminationStatus
            )
        }.value
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
