import Combine
import Foundation

public enum TranscriptInsightPhase: Equatable, Sendable {
    case empty
    case invalidURL(message: String)
    case checkingTranscript
    case downloadingAudio
    case retryingDownload
    case preparingAudio
    case transcribingAudio
    case formattingTranscript
    case complete
    case transcriptFailed(message: String)
}

public enum TranscriptAcquisitionProgress: String, Equatable, Sendable {
    case downloadingAudio = "downloading_audio"
    case retryingDownload = "retrying_download"
    case preparingAudio = "preparing_audio"
    case transcribingAudio = "transcribing_audio"
    case formattingTranscript = "formatting_transcript"
}

public enum TranscriptInsightAction: Equatable, Sendable {
    case urlChanged(String)
    case submit
    case submitFromKeyboard
    case retry
}

public enum TranscriptSource: String, Equatable, Sendable {
    case youtubeCaptions = "youtube_captions"
    case tiktokCaptions = "tiktok_captions"
    case speechToText = "speech_to_text"

    public var displayName: String {
        switch self {
        case .youtubeCaptions: return "YouTube captions"
        case .tiktokCaptions: return "TikTok captions"
        case .speechToText: return "Speech-to-text"
        }
    }
}

public struct Transcript: Equatable, Sendable {
    public let source: TranscriptSource
    public let sentences: [String]
    public let cleanupWarning: String?

    public init(source: TranscriptSource, sentences: [String], cleanupWarning: String? = nil) {
        self.source = source
        self.sentences = sentences
        self.cleanupWarning = cleanupWarning
    }
}

public struct TranscriptBackendFailure: Error, Equatable, Sendable {
    public let kind: String
    public let message: String

    public init(kind: String, message: String) {
        self.kind = kind
        self.message = message
    }

    public var permitsSpeechToTextFallback: Bool {
        kind == "captions_unavailable"
    }
}

public struct TranscriptAcquisitionClient: Sendable {
    public let captions: @Sendable (URL) async throws -> Transcript
    public let speechToText: @Sendable (
        URL,
        @escaping @Sendable (TranscriptAcquisitionProgress) async -> Void
    ) async throws -> Transcript

    public init(
        captions: @escaping @Sendable (URL) async throws -> Transcript,
        speechToText: @escaping @Sendable (URL) async throws -> Transcript
    ) {
        self.captions = captions
        self.speechToText = { url, _ in try await speechToText(url) }
    }

    public init(
        captions: @escaping @Sendable (URL) async throws -> Transcript,
        speechToTextWithProgress: @escaping @Sendable (
            URL,
            @escaping @Sendable (TranscriptAcquisitionProgress) async -> Void
        ) async throws -> Transcript
    ) {
        self.captions = captions
        self.speechToText = speechToTextWithProgress
    }
}

@MainActor
public final class TranscriptInsightStore: ObservableObject {
    public static let malformedURLMessage = "Enter a valid video URL."
    public static let unsupportedHostMessage = "Use a YouTube or TikTok link."

    @Published public private(set) var enteredURL: String
    @Published public private(set) var submittedURL: URL?
    @Published public private(set) var phase: TranscriptInsightPhase
    @Published public private(set) var transcript: Transcript?

    private let onTranscriptRequested: @MainActor (URL) -> Void
    private let acquisitionClient: TranscriptAcquisitionClient?
    private var acquisitionTask: Task<Void, Never>?

    public init(
        enteredURL: String = "",
        phase: TranscriptInsightPhase = .empty,
        transcript: Transcript? = nil,
        acquisitionClient: TranscriptAcquisitionClient? = nil,
        onTranscriptRequested: @escaping @MainActor (URL) -> Void = { _ in }
    ) {
        self.enteredURL = enteredURL
        self.phase = phase
        self.transcript = transcript
        self.acquisitionClient = acquisitionClient
        self.onTranscriptRequested = onTranscriptRequested
    }

    public var canSubmit: Bool {
        guard !isURLLocked else { return false }
        if case .supported = validation { return true }
        return false
    }

    public var isURLLocked: Bool {
        switch phase {
        case .checkingTranscript, .downloadingAudio, .retryingDownload, .preparingAudio,
             .transcribingAudio, .formattingTranscript:
            return true
        default:
            return false
        }
    }

    public var validationMessage: String? {
        if case .invalidURL(let message) = phase { return message }
        return nil
    }

    public var processingStatus: String? {
        switch phase {
        case .checkingTranscript: return "Checking for transcript..."
        case .downloadingAudio: return "Downloading audio..."
        case .retryingDownload: return "TikTok changed its response. Retrying download..."
        case .preparingAudio: return "Preparing audio..."
        case .transcribingAudio: return "Uploading and transcribing..."
        case .formattingTranscript: return "Formatting transcript..."
        default: return nil
        }
    }

    public var errorMessage: String? {
        if case .transcriptFailed(let message) = phase { return message }
        return nil
    }

    public func send(_ action: TranscriptInsightAction) {
        switch action {
        case .urlChanged(let value):
            guard !isURLLocked else { return }
            enteredURL = value
            phase = phase(for: validation)

        case .submit, .submitFromKeyboard:
            guard case .supported(let url) = validation, !isURLLocked else { return }
            startAcquisition(url)

        case .retry:
            guard let url = submittedURL, !isURLLocked else { return }
            startAcquisition(url)
        }
    }

    private func startAcquisition(_ url: URL) {
        acquisitionTask?.cancel()
        submittedURL = url
        transcript = nil
        phase = .checkingTranscript
        onTranscriptRequested(url)

        guard let acquisitionClient else { return }
        acquisitionTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await acquisitionClient.captions(url)
                guard !Task.isCancelled else { return }
                transcript = result
                phase = .complete
            } catch let failure as TranscriptBackendFailure where failure.permitsSpeechToTextFallback {
                guard !Task.isCancelled else { return }
                phase = .downloadingAudio
                do {
                    let result = try await acquisitionClient.speechToText(url) { [weak self] progress in
                        guard !Task.isCancelled else { return }
                        await self?.show(progress)
                    }
                    guard !Task.isCancelled else { return }
                    transcript = result
                    phase = .complete
                } catch {
                    guard !Task.isCancelled else { return }
                    phase = .transcriptFailed(message: Self.message(for: error))
                }
            } catch {
                guard !Task.isCancelled else { return }
                phase = .transcriptFailed(message: Self.message(for: error))
            }
        }
    }

    private func show(_ progress: TranscriptAcquisitionProgress) {
        switch progress {
        case .downloadingAudio: phase = .downloadingAudio
        case .retryingDownload: phase = .retryingDownload
        case .preparingAudio: phase = .preparingAudio
        case .transcribingAudio: phase = .transcribingAudio
        case .formattingTranscript: phase = .formattingTranscript
        }
    }

    private static func message(for error: Error) -> String {
        if let failure = error as? TranscriptBackendFailure { return failure.message }
        return "We couldn’t retrieve a transcript. Try again."
    }

    private var validation: URLValidation {
        Self.validate(enteredURL)
    }

    private func phase(for validation: URLValidation) -> TranscriptInsightPhase {
        switch validation {
        case .blank, .supported:
            return .empty
        case .malformed:
            return .invalidURL(message: Self.malformedURLMessage)
        case .unsupportedHost:
            return .invalidURL(message: Self.unsupportedHostMessage)
        }
    }

    private static func validate(_ input: String) -> URLValidation {
        let candidate = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return .blank }
        guard
            let components = URLComponents(string: candidate),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            let host = components.host?.lowercased(),
            let url = components.url
        else {
            return .malformed
        }

        let isYouTube = host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")
        let isTikTok = host == "tiktok.com" || host.hasSuffix(".tiktok.com")
        guard isYouTube || isTikTok else { return .unsupportedHost }
        return .supported(url)
    }
}

private enum URLValidation {
    case blank
    case malformed
    case unsupportedHost
    case supported(URL)
}
