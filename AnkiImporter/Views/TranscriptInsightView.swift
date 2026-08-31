import AppKit
import SwiftUI
import TranscriptInsightCore

struct TranscriptInsightView: View {
    @Binding private var selectedFeature: FeatureID?
    @StateObject private var store: TranscriptInsightStore
    @FocusState private var isURLFieldFocused: Bool
    @State private var copyFeedback: String?

    @MainActor
    init(selectedFeature: Binding<FeatureID?>) {
        _selectedFeature = selectedFeature
        _store = StateObject(
            wrappedValue: TranscriptInsightStore(acquisitionClient: TranscriptBackend.live)
        )
    }

    @MainActor
    init(selectedFeature: Binding<FeatureID?>, store: TranscriptInsightStore) {
        _selectedFeature = selectedFeature
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                VStack(spacing: 24) {
                    urlCard
                    transcriptCard
                }
                .padding(32)
            }
        }
        .task {
            guard !store.isURLLocked else { return }
            isURLFieldFocused = true
        }
    }

    private var header: some View {
        HStack {
            Button(action: { selectedFeature = nil }) {
                Text("← Back to Home")
                    .font(AppTheme.displayFont(size: 16))
                    .foregroundColor(AppTheme.background)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Home")
            .frame(width: 180, alignment: .leading)

            Spacer()

            Text("Transcript Insight")
                .font(AppTheme.displayFont(size: 32))
                .foregroundColor(AppTheme.text)

            Spacer()

            HStack {
                Spacer()
                Button(action: {}) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.background)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.card)
                        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 4))
                }
                .buttonStyle(.plain)
                .disabled(true)
                .accessibilityLabel("Transcript history")
                .help("History coming soon")
            }
            .frame(width: 180)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.card)
        .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 4), alignment: .bottom)
    }

    private var urlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video URL")
                .font(AppTheme.displayFont(size: 20))
                .foregroundColor(AppTheme.text)

            ZStack(alignment: .leading) {
                if store.enteredURL.isEmpty {
                    Text("Paste a YouTube, TikTok, or Instagram URL...")
                        .font(AppTheme.inputFont())
                        .foregroundColor(AppTheme.text.opacity(0.85))
                        .allowsHitTesting(false)
                }

                TextField(
                    "",
                    text: Binding(
                        get: { store.enteredURL },
                        set: { store.send(.urlChanged($0)) }
                    )
                )
                .font(AppTheme.inputFont())
                .foregroundStyle(AppTheme.text)
                .tint(AppTheme.primary)
                .textFieldStyle(.plain)
                .disabled(store.isURLLocked)
                .focused($isURLFieldFocused)
                .onSubmit { store.send(.submitFromKeyboard) }
                .accessibilityLabel("YouTube, TikTok, or Instagram video URL")
            }
            .padding(16)
            .background(AppTheme.background)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.primary, lineWidth: 4)
                    .allowsHitTesting(false)
            )

            Text(TranscriptBackend.providerDescription)
                .font(AppTheme.inputFont(size: 13))
                .foregroundColor(AppTheme.text.opacity(0.8))

            if let message = store.validationMessage {
                Text(message)
                    .font(AppTheme.inputFont(size: 14))
                    .foregroundColor(AppTheme.destructive)
                    .accessibilityLabel("URL error: \(message)")
            }

            Button(action: { store.send(.submit) }) {
                HStack(spacing: 10) {
                    if store.isURLLocked {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.background)
                    }

                    Text(store.processingStatus ?? "Get Transcript")
                        .font(AppTheme.displayFont(size: 16))
                }
                .foregroundColor(AppTheme.background)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(store.canSubmit || store.isURLLocked ? AppTheme.primary : AppTheme.primary.opacity(0.55))
                .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 4))
            }
            .buttonStyle(.plain)
            .disabled(!store.canSubmit)
            .accessibilityLabel(store.processingStatus ?? "Get Transcript")
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .overlay(
            Rectangle()
                .stroke(AppTheme.primary, lineWidth: 4)
                .allowsHitTesting(false)
        )
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcript")
                        .font(AppTheme.displayFont(size: 20))
                        .foregroundColor(AppTheme.text)
                    if let transcript = store.transcript {
                        Text("Source: \(transcript.source.displayName)")
                            .font(AppTheme.inputFont(size: 14))
                            .foregroundColor(AppTheme.text.opacity(0.8))
                    }
                }

                Spacer()

                if store.transcript != nil {
                    Button(action: copyTranscript) {
                        Image(systemName: copyFeedback == nil ? "doc.on.doc" : "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.background)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.primary)
                            .overlay(Rectangle().stroke(AppTheme.primary, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(copyFeedback ?? "Copy transcript")
                    .help("Copy transcript")
                }
            }

            Group {
                if let transcript = store.transcript {
                    transcriptRows(transcript)
                } else if store.isURLLocked {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppTheme.primary)
                        Text(store.processingStatus ?? "")
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = store.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                        Text(error)
                            .multilineTextAlignment(.center)
                        Button("Try URL Again") { store.send(.retry) }
                            .font(AppTheme.displayFont(size: 16))
                            .foregroundColor(AppTheme.background)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(AppTheme.primary)
                            .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 32))
                        Text("Your transcript will appear here after you add a video link.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .font(AppTheme.inputFont(size: 16))
            .foregroundColor(AppTheme.text.opacity(0.75))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.primary, lineWidth: 4)
                    .allowsHitTesting(false)
            )

            if let warning = store.transcript?.cleanupWarning {
                Text(warning)
                    .font(AppTheme.inputFont(size: 13))
                    .foregroundColor(AppTheme.destructive)
            }

            if let copyFeedback {
                Text(copyFeedback)
                    .font(AppTheme.inputFont(size: 14))
                    .foregroundColor(AppTheme.primary)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .overlay(
            Rectangle()
                .stroke(AppTheme.primary, lineWidth: 4)
                .allowsHitTesting(false)
        )
    }

    private func transcriptRows(_ transcript: Transcript) -> some View {
        ScrollView(.vertical) {
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(transcript.sentences.enumerated()), id: \.offset) { _, sentence in
                        Text(sentence)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .padding(16)
                .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func copyTranscript() {
        guard let transcript = store.transcript else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript.sentences.joined(separator: "\n"), forType: .string)
        copyFeedback = "Transcript copied"
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copyFeedback = nil
        }
    }
}

@MainActor
private struct TranscriptInsightPreview: View {
    let enteredURL: String
    let phase: TranscriptInsightPhase
    var transcript: Transcript? = nil
    var width: CGFloat = 1200
    var height: CGFloat = 800
    @State private var selectedFeature: FeatureID? = .transcriptInsight

    var body: some View {
        TranscriptInsightView(
            selectedFeature: $selectedFeature,
            store: TranscriptInsightStore(enteredURL: enteredURL, phase: phase, transcript: transcript)
        )
        .frame(width: width, height: height)
    }
}

struct TranscriptInsightView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TranscriptInsightPreview(enteredURL: "", phase: .empty)
                .previewDisplayName("Empty")
            TranscriptInsightPreview(
                enteredURL: "https://example.com/video",
                phase: .invalidURL(message: TranscriptInsightStore.unsupportedHostMessage)
            )
            .previewDisplayName("Invalid URL")
            TranscriptInsightPreview(
                enteredURL: "https://youtu.be/dQw4w9WgXcQ",
                phase: .checkingTranscript
            )
            .previewDisplayName("Checking")
            TranscriptInsightPreview(
                enteredURL: "https://youtu.be/dQw4w9WgXcQ",
                phase: .transcribingAudio
            )
            .previewDisplayName("Transcribing")
            TranscriptInsightPreview(
                enteredURL: "https://youtu.be/dQw4w9WgXcQ",
                phase: .complete,
                transcript: Transcript(
                    source: .youtubeCaptions,
                    sentences: [
                        "The first caption sentence stays on one selectable row.",
                        "This deliberately long caption sentence remains complete and horizontally scrollable so that the interface never hides source meaning behind an ellipsis or silent truncation.",
                        "Repeated spoken content stays present when it genuinely occurs.",
                        "Repeated spoken content stays present when it genuinely occurs.",
                    ]
                )
            )
            .previewDisplayName("YouTube Captions")
            TranscriptInsightPreview(
                enteredURL: "https://www.tiktok.com/@creator/video/123",
                phase: .complete,
                transcript: Transcript(source: .speechToText, sentences: ["Speech-to-text result."])
            )
            .previewDisplayName("Speech-to-text")
            TranscriptInsightPreview(
                enteredURL: "https://youtu.be/private",
                phase: .transcriptFailed(message: "This video is unavailable or private. Try another link.")
            )
            .previewDisplayName("Fallback Failure")
            TranscriptInsightPreview(
                enteredURL: "https://youtu.be/dQw4w9WgXcQ",
                phase: .checkingTranscript,
                width: 1440,
                height: 1000
            )
            .previewDisplayName("Checking — Large Desktop")
        }
    }
}
