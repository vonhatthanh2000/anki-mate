import Combine
import Foundation

public enum TranscriptInsightPhase: Equatable, Sendable {
    case empty
    case invalidURL(message: String)
    case checkingTranscript
}

public enum TranscriptInsightAction: Equatable, Sendable {
    case urlChanged(String)
    case submit
    case submitFromKeyboard
}

@MainActor
public final class TranscriptInsightStore: ObservableObject {
    public static let malformedURLMessage = "Enter a valid video URL."
    public static let unsupportedHostMessage = "Use a YouTube or TikTok link."

    @Published public private(set) var enteredURL: String
    @Published public private(set) var submittedURL: URL?
    @Published public private(set) var phase: TranscriptInsightPhase

    private let onTranscriptRequested: @MainActor (URL) -> Void

    public init(
        enteredURL: String = "",
        phase: TranscriptInsightPhase = .empty,
        onTranscriptRequested: @escaping @MainActor (URL) -> Void = { _ in }
    ) {
        self.enteredURL = enteredURL
        self.phase = phase
        self.onTranscriptRequested = onTranscriptRequested
    }

    public var canSubmit: Bool {
        guard !isURLLocked else { return false }
        if case .supported = validation { return true }
        return false
    }

    public var isURLLocked: Bool {
        phase == .checkingTranscript
    }

    public var validationMessage: String? {
        if case .invalidURL(let message) = phase { return message }
        return nil
    }

    public var processingStatus: String? {
        phase == .checkingTranscript ? "Checking for transcript..." : nil
    }

    public func send(_ action: TranscriptInsightAction) {
        switch action {
        case .urlChanged(let value):
            guard !isURLLocked else { return }
            enteredURL = value
            phase = phase(for: validation)

        case .submit, .submitFromKeyboard:
            guard case .supported(let url) = validation, !isURLLocked else { return }
            submittedURL = url
            phase = .checkingTranscript
            onTranscriptRequested(url)
        }
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
