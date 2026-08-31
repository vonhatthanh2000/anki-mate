import AppKit
import CryptoKit
import Foundation
import Network
import Security
import TranscriptInsightCore

enum TranscriptBackend {
    enum Provider: String, Sendable {
        case tokScript = "tokscript"
        case gpt = "gpt"
    }

    static let provider = configuredProvider()

    static let live: TranscriptAcquisitionClient = {
        switch provider {
        case .tokScript:
            return tokScript
        case .gpt:
            return PythonTranscriptBackend.live
        }
    }()

    static var providerDescription: String {
        switch provider {
        case .tokScript:
            return "Using TokScript. The first request opens sign-in; failures are shown without switching to GPT."
        case .gpt:
            return "Using GPT audio transcription. Media is downloaded and prepared before transcription."
        }
    }

    private static let tokScript = TranscriptAcquisitionClient(
        acquireWithProgress: { url, progress in
            await progress(.requestingTokScript)
            do {
                return try await TokScriptClient.shared.transcript(for: url)
            } catch {
                throw TranscriptBackendFailure(
                    kind: "tokscript_failed",
                    message: TokScriptError.message(for: error)
                )
            }
        }
    )

    private static func configuredProvider() -> Provider {
        let rawValue = ProcessInfo.processInfo.environment["TRANSCRIPT_PROVIDER"]
            ?? envFileValue(for: "TRANSCRIPT_PROVIDER")
            ?? Provider.tokScript.rawValue
        return Provider(rawValue: rawValue.lowercased()) ?? .tokScript
    }

    private static func envFileValue(for key: String) -> String? {
        let fileManager = FileManager.default
        let optionalPaths: [String?] = [
            Bundle.main.resourceURL?.appendingPathComponent(".env").path,
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(".env").path,
            fileManager.currentDirectoryPath + "/.env",
            fileManager.currentDirectoryPath + "/../.env",
        ]
        let paths = optionalPaths.compactMap { $0 }

        for path in paths where fileManager.fileExists(atPath: path) {
            guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            for line in contents.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#"),
                      let separator = trimmed.firstIndex(of: "=") else { continue }
                let candidateKey = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
                guard candidateKey == key else { continue }
                return String(trimmed[trimmed.index(after: separator)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return nil
    }
}

private actor TokScriptClient {
    static let shared = TokScriptClient()

    private let endpoint = URL(string: "https://api.tokscript.com/mcp")!
    private let authenticator = TokScriptAuthenticator()
    private let session = URLSession.shared

    func transcript(for videoURL: URL) async throws -> Transcript {
        let token = try await authenticator.accessToken()
        let initialized = try await request(
            method: "initialize",
            params: [
                "protocolVersion": "2025-06-18",
                "capabilities": [:],
                "clientInfo": ["name": "Anki Mate", "version": "1.0"],
            ],
            id: 1,
            token: token,
            sessionID: nil
        )
        let sessionID = initialized.sessionID
        try await notifyInitialized(token: token, sessionID: sessionID)

        let listed = try await request(
            method: "tools/list",
            params: [:],
            id: 2,
            token: token,
            sessionID: sessionID
        )
        let toolName = Self.toolName(for: videoURL)
        guard let tool = Self.tool(named: toolName, in: listed.object),
              let argumentName = Self.urlArgumentName(in: tool)
        else {
            throw TokScriptError.invalidResponse("TokScript did not advertise the expected transcript tool.")
        }

        let called = try await request(
            method: "tools/call",
            params: ["name": toolName, "arguments": [argumentName: videoURL.absoluteString]],
            id: 3,
            token: token,
            sessionID: sessionID
        )
        if let result = called.object["result"] as? [String: Any], result["isError"] as? Bool == true {
            let message = (result["content"] as? [[String: Any]])?
                .compactMap { $0["text"] as? String }
                .joined(separator: " ")
            throw TokScriptError.requestFailed(
                message.flatMap { $0.isEmpty ? nil : $0 } ?? "TokScript could not transcribe this video."
            )
        }
        let sentences = TokScriptTranscriptParser.sentences(from: called.object)
        guard !sentences.isEmpty else {
            throw TokScriptError.invalidResponse("TokScript returned an empty transcript.")
        }
        return Transcript(source: .tokScript, sentences: sentences)
    }

    private func notifyInitialized(token: String, sessionID: String?) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("2025-06-18", forHTTPHeaderField: "MCP-Protocol-Version")
        if let sessionID { request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id") }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
        ])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TokScriptError.requestFailed("TokScript initialization failed.")
        }
    }

    private func request(
        method: String,
        params: [String: Any],
        id: Int,
        token: String,
        sessionID: String?
    ) async throws -> MCPResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if method != "initialize" {
            request.setValue("2025-06-18", forHTTPHeaderField: "MCP-Protocol-Version")
        }
        if let sessionID { request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id") }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params,
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TokScriptError.requestFailed("TokScript returned an invalid HTTP response.")
        }
        if http.statusCode == 401 {
            await authenticator.invalidateAccessToken()
            throw TokScriptError.authenticationRequired
        }
        guard (200..<300).contains(http.statusCode) else {
            throw TokScriptError.requestFailed("TokScript returned HTTP \(http.statusCode).")
        }
        let object = try Self.decodeMCPObject(data)
        if let error = object["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "TokScript MCP request failed."
            throw TokScriptError.requestFailed(message)
        }
        return MCPResponse(
            object: object,
            sessionID: http.value(forHTTPHeaderField: "Mcp-Session-Id")
        )
    }

    private static func decodeMCPObject(_ data: Data) throws -> [String: Any] {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }
        let body = String(decoding: data, as: UTF8.self)
        for line in body.split(whereSeparator: \.isNewline) {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if let data = payload.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return object
            }
        }
        throw TokScriptError.invalidResponse("TokScript returned an unreadable MCP response.")
    }

    private static func toolName(for url: URL) -> String {
        let host = url.host?.lowercased() ?? ""
        if host.contains("instagram") || host == "instagr.am" { return "get_instagram_transcript" }
        if host.contains("youtube") || host == "youtu.be" { return "get_youtube_transcript" }
        return "get_tiktok_transcript"
    }

    private static func tool(named name: String, in response: [String: Any]) -> [String: Any]? {
        guard let result = response["result"] as? [String: Any],
              let tools = result["tools"] as? [[String: Any]]
        else { return nil }
        return tools.first { $0["name"] as? String == name }
    }

    private static func urlArgumentName(in tool: [String: Any]) -> String? {
        guard let schema = tool["inputSchema"] as? [String: Any],
              let properties = schema["properties"] as? [String: Any]
        else { return "url" }
        return properties.keys.first(where: { $0.lowercased().contains("url") })
            ?? (schema["required"] as? [String])?.first
            ?? "url"
    }
}

private actor TokScriptAuthenticator {
    private let registrationURL = URL(string: "https://api.tokscript.com/api/connector/oauth/register")!
    private let authorizationURL = URL(string: "https://api.tokscript.com/api/connector/oauth/authorize")!
    private let tokenURL = URL(string: "https://api.tokscript.com/api/connector/oauth/token")!
    private let store = TokScriptCredentialStore()

    func accessToken() async throws -> String {
        if let credentials = try store.load(), credentials.expiresAt > Date().addingTimeInterval(30) {
            return credentials.accessToken
        }
        if let credentials = try store.load(), let refreshToken = credentials.refreshToken {
            do {
                let refreshed = try await exchange([
                    "grant_type": "refresh_token",
                    "refresh_token": refreshToken,
                    "client_id": credentials.clientID,
                    "resource": "https://api.tokscript.com/mcp",
                ], clientID: credentials.clientID, redirectURI: credentials.redirectURI, fallbackRefreshToken: refreshToken)
                try store.save(refreshed)
                return refreshed.accessToken
            } catch {
                try? store.delete()
            }
        }
        return try await authorize()
    }

    func invalidateAccessToken() {
        guard let current = try? store.load() else { return }
        let expired = TokScriptCredentials(
            clientID: current.clientID,
            redirectURI: current.redirectURI,
            accessToken: current.accessToken,
            refreshToken: current.refreshToken,
            expiresAt: .distantPast
        )
        try? store.save(expired)
    }

    private func authorize() async throws -> String {
        let receiver = try await LoopbackOAuthReceiver.start()
        defer { receiver.cancel() }
        let redirectURI = "http://127.0.0.1:\(receiver.port)/oauth/callback"
        let clientID: String
        if let saved = try store.load(), saved.redirectURI == redirectURI {
            clientID = saved.clientID
        } else {
            clientID = try await register(redirectURI: redirectURI)
        }

        let verifier = Self.randomURLSafeString(byteCount: 48)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = Self.randomURLSafeString(byteCount: 24)
        var components = URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "mcp:access"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "resource", value: "https://api.tokscript.com/mcp"),
        ]
        guard let loginURL = components.url else { throw TokScriptError.authenticationRequired }
        _ = await MainActor.run { NSWorkspace.shared.open(loginURL) }

        let callback = try await receiver.waitForCallback()
        let callbackComponents = URLComponents(url: callback, resolvingAgainstBaseURL: false)
        let values = Dictionary(uniqueKeysWithValues: (callbackComponents?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        guard values["state"] == state, let code = values["code"], !code.isEmpty else {
            throw TokScriptError.authenticationRequired
        }
        let credentials = try await exchange([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier,
            "client_id": clientID,
            "resource": "https://api.tokscript.com/mcp",
        ], clientID: clientID, redirectURI: redirectURI)
        try store.save(credentials)
        return credentials.accessToken
    }

    private func register(redirectURI: String) async throws -> String {
        var request = URLRequest(url: registrationURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "client_name": "Anki Mate",
            "redirect_uris": [redirectURI],
            "grant_types": ["authorization_code", "refresh_token"],
            "response_types": ["code"],
            "token_endpoint_auth_method": "none",
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let clientID = object["client_id"] as? String
        else { throw TokScriptError.authenticationRequired }
        return clientID
    }

    private func exchange(
        _ fields: [String: String],
        clientID: String,
        redirectURI: String = "",
        fallbackRefreshToken: String? = nil
    ) async throws -> TokScriptCredentials {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { key, value in "\(Self.formEncode(key))=\(Self.formEncode(value))" }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = object["access_token"] as? String
        else { throw TokScriptError.authenticationRequired }
        let expiresIn = (object["expires_in"] as? NSNumber)?.doubleValue
            ?? (object["expires_in"] as? String).flatMap(Double.init)
            ?? 3600
        return TokScriptCredentials(
            clientID: clientID,
            redirectURI: redirectURI,
            accessToken: accessToken,
            refreshToken: object["refresh_token"] as? String ?? fallbackRefreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
    }

    private static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
    }
}

private final class LoopbackOAuthReceiver: @unchecked Sendable {
    let port: UInt16
    private let listener: NWListener
    private let lock = NSLock()
    private var callbackContinuation: CheckedContinuation<URL, Error>?
    private var receivedURL: URL?
    private var timeoutWorkItem: DispatchWorkItem?

    private init(listener: NWListener, port: UInt16) {
        self.listener = listener
        self.port = port
        listener.newConnectionHandler = { [weak self] connection in self?.receive(connection) }
    }

    static func start() async throws -> LoopbackOAuthReceiver {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        let listener = try NWListener(using: parameters)
        return try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard let port = listener.port else {
                        continuation.resume(throwing: TokScriptError.authenticationRequired)
                        return
                    }
                    listener.stateUpdateHandler = nil
                    continuation.resume(returning: LoopbackOAuthReceiver(listener: listener, port: port.rawValue))
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: .global(qos: .userInitiated))
        }
    }

    func waitForCallback() async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if let receivedURL {
                    lock.unlock()
                    continuation.resume(returning: receivedURL)
                } else {
                    callbackContinuation = continuation
                    let timeout = DispatchWorkItem { [weak self] in
                        self?.fail(TokScriptError.authenticationRequired)
                    }
                    timeoutWorkItem = timeout
                    lock.unlock()
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 120, execute: timeout)
                }
            }
        } onCancel: {
            fail(CancellationError())
        }
    }

    func cancel() {
        listener.cancel()
    }

    private func receive(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8),
                  let target = request.split(separator: "\n").first?.split(separator: " ").dropFirst().first,
                  let url = URL(string: "http://127.0.0.1:\(self.port)\(target)")
            else {
                connection.cancel()
                return
            }
            let body = "Authentication complete. You can return to Anki Mate."
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
            self.complete(url)
        }
    }

    private func complete(_ url: URL) {
        lock.lock()
        receivedURL = url
        let continuation = callbackContinuation
        callbackContinuation = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        lock.unlock()
        continuation?.resume(returning: url)
    }

    private func fail(_ error: Error) {
        lock.lock()
        let continuation = callbackContinuation
        callbackContinuation = nil
        timeoutWorkItem = nil
        lock.unlock()
        continuation?.resume(throwing: error)
        listener.cancel()
    }
}

private struct TokScriptCredentialStore: Sendable {
    private let service = "com.ankimate.tokscript"
    private let account = "oauth"

    func load() throws -> TokScriptCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw TokScriptError.keychain(status)
        }
        return try JSONDecoder().decode(TokScriptCredentials.self, from: data)
    }

    func save(_ credentials: TokScriptCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let update = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if update == errSecItemNotFound {
            var item = identity
            item[kSecValueData as String] = data
            let add = SecItemAdd(item as CFDictionary, nil)
            guard add == errSecSuccess else { throw TokScriptError.keychain(add) }
        } else if update != errSecSuccess {
            throw TokScriptError.keychain(update)
        }
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokScriptError.keychain(status)
        }
    }
}

private struct TokScriptCredentials: Codable, Sendable {
    let clientID: String
    let redirectURI: String
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

private struct MCPResponse {
    let object: [String: Any]
    let sessionID: String?
}

private enum TokScriptError: Error {
    case authenticationRequired
    case invalidResponse(String)
    case requestFailed(String)
    case keychain(OSStatus)
}

private extension TokScriptError {
    private static func knownMessage(for error: TokScriptError) -> String {
        switch error {
        case .authenticationRequired:
            return "TokScript sign-in was not completed. Try again and finish signing in."
        case .requestFailed(let message), .invalidResponse(let message):
            return message
        case .keychain(let status):
            let detail = SecCopyErrorMessageString(status, nil) as String?
            return "TokScript Keychain error \(status): \(detail ?? "Unknown Security framework error.")"
        }
    }

    static func message(for error: Error) -> String {
        if let error = error as? TokScriptError {
            return knownMessage(for: error)
        }
        if let error = error as? URLError {
            return "TokScript network error \(error.errorCode) (\(error.code)): \(error.localizedDescription)"
        }
        if let error = error as? DecodingError {
            return "TokScript decoding error: \(decodingMessage(error))"
        }

        let cocoaError = error as NSError
        return "TokScript error [\(cocoaError.domain) \(cocoaError.code), \(String(reflecting: type(of: error)))]: \(cocoaError.localizedDescription)"
    }

    private static func decodingMessage(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted(let context):
            return "Data corrupted at \(codingPath(context)): \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "Missing key '\(key.stringValue)' at \(codingPath(context)): \(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "Expected \(type) at \(codingPath(context)): \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Missing \(type) at \(codingPath(context)): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }

    private static func codingPath(_ context: DecodingError.Context) -> String {
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? "<root>" : path
    }
}

private enum TokScriptTranscriptParser {
    static func sentences(from response: [String: Any]) -> [String] {
        guard let result = response["result"] as? [String: Any] else { return [] }
        if let structured = result["structuredContent"], let transcript = extract(structured), !transcript.isEmpty {
            return transcript
        }
        guard let content = result["content"] as? [[String: Any]] else { return [] }
        for item in content where item["type"] as? String == "text" {
            guard let text = item["text"] as? String else { continue }
            if let data = text.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data),
               let transcript = extract(object), !transcript.isEmpty {
                return transcript
            }
            let transcript = split(text)
            if !transcript.isEmpty { return transcript }
        }
        return []
    }

    private static func extract(_ value: Any) -> [String]? {
        if let object = value as? [String: Any] {
            for key in ["transcript", "captions", "segments", "sentences", "text"] {
                if let nested = object[key], let result = extract(nested), !result.isEmpty { return result }
            }
            for nested in object.values {
                if let result = extract(nested), !result.isEmpty { return result }
            }
        } else if let values = value as? [Any] {
            let segments = values.compactMap { item -> String? in
                if let text = item as? String { return text }
                guard let object = item as? [String: Any] else { return nil }
                return object["text"] as? String ?? object["caption"] as? String
            }
            if !segments.isEmpty { return segments.flatMap(split) }
        } else if let text = value as? String {
            return split(text)
        }
        return nil
    }

    private static func split(_ text: String) -> [String] {
        let cleaned = text
            .replacingOccurrences(of: #"(?m)^\s*(?:\[?\d{1,2}:)?\d{1,2}:\d{2}(?:\.\d+)?\]?\s*[-–—:]?\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }
        let pattern = #"[^.!?\n]+(?:[.!?]+|$)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [cleaned] }
        let range = NSRange(cleaned.startIndex..., in: cleaned)
        return expression.matches(in: cleaned, range: range).compactMap { match in
            guard let range = Range(match.range, in: cleaned) else { return nil }
            let sentence = cleaned[range].trimmingCharacters(in: .whitespacesAndNewlines)
            return sentence.isEmpty ? nil : sentence
        }
    }
}
