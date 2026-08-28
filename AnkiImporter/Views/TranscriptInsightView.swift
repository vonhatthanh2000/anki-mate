import SwiftUI
import TranscriptInsightCore

struct TranscriptInsightView: View {
    @Binding private var selectedFeature: FeatureID?
    @StateObject private var store: TranscriptInsightStore
    @FocusState private var isURLFieldFocused: Bool

    @MainActor
    init(selectedFeature: Binding<FeatureID?>) {
        _selectedFeature = selectedFeature
        _store = StateObject(wrappedValue: TranscriptInsightStore())
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
                    transcriptPlaceholder
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

            TextField(
                "Paste a YouTube or TikTok URL...",
                text: Binding(
                    get: { store.enteredURL },
                    set: { store.send(.urlChanged($0)) }
                )
            )
            .font(AppTheme.inputFont())
            .foregroundStyle(AppTheme.text)
            .tint(AppTheme.primary)
            .textFieldStyle(.plain)
            .padding(16)
            .background(AppTheme.background)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.primary, lineWidth: 4)
                    .allowsHitTesting(false)
            )
            .disabled(store.isURLLocked)
            .focused($isURLFieldFocused)
            .onSubmit { store.send(.submitFromKeyboard) }
            .accessibilityLabel("YouTube or TikTok video URL")

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

    private var transcriptPlaceholder: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcript")
                .font(AppTheme.displayFont(size: 20))
                .foregroundColor(AppTheme.text)

            VStack(spacing: 16) {
                if store.isURLLocked {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppTheme.primary)
                    Text(store.processingStatus ?? "")
                        .accessibilityAddTraits(.updatesFrequently)
                } else {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 32))
                    Text("Your transcript will appear here after you add a video link.")
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
            .accessibilityElement(children: .combine)
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
}

@MainActor
private struct TranscriptInsightPreview: View {
    let enteredURL: String
    let phase: TranscriptInsightPhase
    var width: CGFloat = 1200
    var height: CGFloat = 800
    @State private var selectedFeature: FeatureID? = .transcriptInsight

    var body: some View {
        TranscriptInsightView(
            selectedFeature: $selectedFeature,
            store: TranscriptInsightStore(enteredURL: enteredURL, phase: phase)
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
                phase: .checkingTranscript,
                width: 1440,
                height: 1000
            )
            .previewDisplayName("Checking — Large Desktop")
        }
    }
}
