import Foundation
import TranscriptInsightCore

@main
struct TranscriptInsightChecks {
    @MainActor
    static func main() async {
        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        func waitFor(_ condition: @escaping @MainActor () -> Bool) async -> Bool {
            for _ in 0..<200 {
                if condition() { return true }
                try? await Task.sleep(nanoseconds: 1_000_000)
            }
            return false
        }

        let blank = TranscriptInsightStore()
        blank.send(.urlChanged("   "))
        expect(blank.phase == .empty, "Blank input should remain empty")
        expect(!blank.canSubmit, "Blank input should not submit")
        expect(blank.validationMessage == nil, "Blank input should stay quiet")

        let invalid = TranscriptInsightStore()
        invalid.send(.urlChanged("this is not a URL"))
        expect(
            invalid.phase == .invalidURL(message: "Enter a valid video URL."),
            "Malformed URLs should have malformed guidance"
        )
        invalid.send(.urlChanged("https://example.com/watch?v=abc"))
        expect(
            invalid.phase == .invalidURL(message: "Use a YouTube or TikTok link."),
            "Unsupported hosts should have host guidance"
        )

        let supportedURLs = [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ",
            "https://www.youtube.com/shorts/dQw4w9WgXcQ",
            "https://www.tiktok.com/@creator/video/7420000000000000000",
            "https://vm.tiktok.com/ZMexample/",
        ]
        for input in supportedURLs {
            let store = TranscriptInsightStore()
            store.send(.urlChanged(input))
            expect(store.canSubmit, "Expected supported URL: \(input)")
            expect(store.validationMessage == nil, "Supported URL should have no error: \(input)")
        }

        var requestedURL: URL?
        let submitted = TranscriptInsightStore(onTranscriptRequested: { requestedURL = $0 })
        let input = "https://youtu.be/dQw4w9WgXcQ?t=4"
        submitted.send(.urlChanged(input))
        submitted.send(.submit)
        expect(submitted.phase == .checkingTranscript, "Submit should enter checking")
        expect(submitted.enteredURL == input, "Submit should retain field value")
        expect(submitted.submittedURL?.absoluteString == input, "Submit should retain exact URL")
        expect(requestedURL?.absoluteString == input, "Submit should call injected boundary")
        expect(submitted.isURLLocked, "Checking should lock URL")
        expect(!submitted.canSubmit, "Checking should prevent duplicate submit")
        expect(submitted.processingStatus == "Checking for transcript...", "Checking status should be visible")

        var buttonRequests: [URL] = []
        let buttonStore = TranscriptInsightStore(onTranscriptRequested: { buttonRequests.append($0) })
        buttonStore.send(.urlChanged("https://www.youtube.com/watch?v=button"))
        buttonStore.send(.submit)

        var keyboardRequests: [URL] = []
        let keyboardStore = TranscriptInsightStore(onTranscriptRequested: { keyboardRequests.append($0) })
        keyboardStore.send(.urlChanged("https://www.youtube.com/watch?v=button"))
        keyboardStore.send(.submitFromKeyboard)
        expect(buttonStore.phase == keyboardStore.phase, "Return and button should enter the same phase")
        expect(buttonRequests == keyboardRequests, "Return and button should request the same exact URL")

        let captionLog = CallLog()
        let captionClient = TranscriptAcquisitionClient(
            captions: { url in
                await captionLog.append("captions:\(url.absoluteString)")
                return Transcript(source: .youtubeCaptions, sentences: ["Caption result."])
            },
            speechToText: { url in
                await captionLog.append("speech:\(url.absoluteString)")
                return Transcript(source: .speechToText, sentences: ["Unexpected fallback."])
            }
        )
        let captionStore = TranscriptInsightStore(acquisitionClient: captionClient)
        captionStore.send(.urlChanged("https://youtu.be/captions"))
        captionStore.send(.submit)
        let captionsCompleted = await waitFor { captionStore.phase == .complete }
        let captionCalls = await captionLog.values
        expect(captionsCompleted, "Caption acquisition should complete")
        expect(captionStore.transcript?.source == .youtubeCaptions, "Caption source should be retained")
        expect(
            captionCalls == ["captions:https://youtu.be/captions"],
            "Successful captions must not trigger speech-to-text"
        )

        let fallbackLog = CallLog()
        let fallbackClient = TranscriptAcquisitionClient(
            captions: { url in
                await fallbackLog.append("captions:\(url.absoluteString)")
                throw TranscriptBackendFailure(kind: "captions_unavailable", message: "No captions")
            },
            speechToTextWithProgress: { url, progress in
                await fallbackLog.append("speech:\(url.absoluteString)")
                await progress(.downloadingAudio)
                try await Task.sleep(nanoseconds: 5_000_000)
                await progress(.preparingAudio)
                try await Task.sleep(nanoseconds: 5_000_000)
                await progress(.transcribingAudio)
                try await Task.sleep(nanoseconds: 5_000_000)
                await progress(.formattingTranscript)
                try await Task.sleep(nanoseconds: 5_000_000)
                return Transcript(source: .speechToText, sentences: ["Spoken result."])
            }
        )
        let fallbackStore = TranscriptInsightStore(acquisitionClient: fallbackClient)
        fallbackStore.send(.urlChanged("https://youtu.be/fallback"))
        fallbackStore.send(.submit)
        let downloadBecameVisible = await waitFor { fallbackStore.phase == .downloadingAudio }
        let preparingBecameVisible = await waitFor { fallbackStore.phase == .preparingAudio }
        let transcribingBecameVisible = await waitFor { fallbackStore.phase == .transcribingAudio }
        let formattingBecameVisible = await waitFor { fallbackStore.phase == .formattingTranscript }
        let fallbackCompleted = await waitFor { fallbackStore.phase == .complete }
        let fallbackCalls = await fallbackLog.values
        expect(downloadBecameVisible, "Fallback should expose the download phase")
        expect(preparingBecameVisible, "Fallback should expose the audio preparation phase")
        expect(transcribingBecameVisible, "Fallback should expose the transcription phase")
        expect(formattingBecameVisible, "Fallback should expose the formatting phase")
        expect(fallbackCompleted, "Eligible fallback should complete")
        expect(fallbackStore.transcript?.source == .speechToText, "Fallback source should be speech-to-text")
        expect(
            fallbackCalls == [
                "captions:https://youtu.be/fallback",
                "speech:https://youtu.be/fallback",
            ],
            "Fallback should preserve order and exact source URL"
        )

        let failureLog = CallLog()
        let failureClient = TranscriptAcquisitionClient(
            captions: { url in
                await failureLog.append("captions:\(url.absoluteString)")
                throw TranscriptBackendFailure(kind: "video_unavailable", message: "This video is private.")
            },
            speechToText: { url in
                await failureLog.append("speech:\(url.absoluteString)")
                return Transcript(source: .speechToText, sentences: ["Must not appear."])
            }
        )
        let failureStore = TranscriptInsightStore(acquisitionClient: failureClient)
        failureStore.send(.urlChanged("https://youtu.be/private"))
        failureStore.send(.submit)
        let failureCompleted = await waitFor {
            failureStore.phase == .transcriptFailed(message: "This video is private.")
        }
        let failureCalls = await failureLog.values
        expect(
            failureCompleted,
            "Non-eligible acquisition errors should remain actionable"
        )
        expect(
            failureCalls == ["captions:https://youtu.be/private"],
            "Private videos must not trigger media processing"
        )

        let retryLog = CallLog()
        let retryClient = TranscriptAcquisitionClient(
            captions: { url in
                await retryLog.append("captions:\(url.absoluteString)")
                throw TranscriptBackendFailure(kind: "captions_unavailable", message: "No captions")
            },
            speechToText: { url in
                await retryLog.append("speech:\(url.absoluteString)")
                throw TranscriptBackendFailure(kind: "transcription_failed", message: "Try transcription again.")
            }
        )
        let retryStore = TranscriptInsightStore(acquisitionClient: retryClient)
        retryStore.send(.urlChanged("https://youtu.be/retry-current"))
        retryStore.send(.submit)
        let firstFailure = await waitFor {
            retryStore.phase == .transcriptFailed(message: "Try transcription again.")
        }
        expect(firstFailure, "Fallback failure should be represented accurately")
        expect(retryStore.transcript == nil, "Fallback failure must not expose an incorrect transcript")
        retryStore.send(.retry)
        expect(retryStore.phase == .checkingTranscript, "Retry should clear the obsolete error immediately")
        let secondFailure = await waitFor {
            retryStore.phase == .transcriptFailed(message: "Try transcription again.")
        }
        let retryCalls = await retryLog.values
        expect(secondFailure, "Retry failure should remain actionable")
        expect(
            retryCalls == [
                "captions:https://youtu.be/retry-current",
                "speech:https://youtu.be/retry-current",
                "captions:https://youtu.be/retry-current",
                "speech:https://youtu.be/retry-current",
            ],
            "Retry should reuse the current submitted URL"
        )

        if failures.isEmpty {
            print("Transcript Insight checks passed (\(supportedURLs.count + 10) scenarios).")
        } else {
            for failure in failures { fputs("FAIL: \(failure)\n", stderr) }
            exit(1)
        }
    }
}

private actor CallLog {
    private var entries: [String] = []

    func append(_ value: String) {
        entries.append(value)
    }

    var values: [String] {
        entries
    }
}
