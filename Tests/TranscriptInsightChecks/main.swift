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
            invalid.phase == .invalidURL(message: "Use a YouTube, TikTok, or Instagram link."),
            "Unsupported hosts should have host guidance"
        )

        let supportedURLs = [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ",
            "https://www.youtube.com/shorts/dQw4w9WgXcQ",
            "https://www.tiktok.com/@creator/video/7420000000000000000",
            "https://vm.tiktok.com/ZMexample/",
            "https://www.instagram.com/reel/example/",
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
            acquireWithProgress: { url, progress in
                await captionLog.append("acquire:\(url.absoluteString)")
                await progress(.requestingTokScript)
                try await Task.sleep(nanoseconds: 5_000_000)
                return Transcript(source: .tokScript, sentences: ["TokScript result."])
            }
        )
        let captionStore = TranscriptInsightStore(acquisitionClient: captionClient)
        captionStore.send(.urlChanged("https://youtu.be/captions"))
        captionStore.send(.submit)
        let tokScriptBecameVisible = await waitFor { captionStore.phase == .requestingTokScript }
        let captionsCompleted = await waitFor { captionStore.phase == .complete }
        let captionCalls = await captionLog.values
        expect(captionsCompleted, "Caption acquisition should complete")
        expect(tokScriptBecameVisible, "TokScript should be visible as the primary transcript provider")
        expect(captionStore.transcript?.source == .tokScript, "TokScript source should be retained")
        expect(
            captionCalls == ["acquire:https://youtu.be/captions"],
            "A request should use exactly one transcript provider"
        )

        let gptLog = CallLog()
        let gptClient = TranscriptAcquisitionClient(
            acquireWithProgress: { url, progress in
                await gptLog.append("gpt:\(url.absoluteString)")
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
        let gptStore = TranscriptInsightStore(acquisitionClient: gptClient)
        gptStore.send(.urlChanged("https://youtu.be/gpt"))
        gptStore.send(.submit)
        let downloadBecameVisible = await waitFor { gptStore.phase == .downloadingAudio }
        let preparingBecameVisible = await waitFor { gptStore.phase == .preparingAudio }
        let transcribingBecameVisible = await waitFor { gptStore.phase == .transcribingAudio }
        let formattingBecameVisible = await waitFor { gptStore.phase == .formattingTranscript }
        let gptCompleted = await waitFor { gptStore.phase == .complete }
        let gptCalls = await gptLog.values
        expect(downloadBecameVisible, "GPT should expose the download phase")
        expect(preparingBecameVisible, "GPT should expose the audio preparation phase")
        expect(transcribingBecameVisible, "GPT should expose the transcription phase")
        expect(formattingBecameVisible, "GPT should expose the formatting phase")
        expect(gptCompleted, "GPT acquisition should complete")
        expect(gptStore.transcript?.source == .speechToText, "GPT source should be speech-to-text")
        expect(
            gptCalls == ["gpt:https://youtu.be/gpt"],
            "GPT should be the only provider called"
        )

        let failureLog = CallLog()
        let failureClient = TranscriptAcquisitionClient(
            acquire: { url in
                await failureLog.append("tokscript:\(url.absoluteString)")
                throw TranscriptBackendFailure(kind: "tokscript_failed", message: "TokScript quota exhausted.")
            }
        )
        let failureStore = TranscriptInsightStore(acquisitionClient: failureClient)
        failureStore.send(.urlChanged("https://youtu.be/private"))
        failureStore.send(.submit)
        let failureCompleted = await waitFor {
            failureStore.phase == .transcriptFailed(message: "TokScript quota exhausted.")
        }
        let failureCalls = await failureLog.values
        expect(
            failureCompleted,
            "Provider errors should remain actionable"
        )
        expect(
            failureCalls == ["tokscript:https://youtu.be/private"],
            "TokScript failure must not trigger GPT"
        )

        let retryLog = CallLog()
        let retryClient = TranscriptAcquisitionClient(
            acquire: { url in
                await retryLog.append("acquire:\(url.absoluteString)")
                throw TranscriptBackendFailure(kind: "transcription_failed", message: "Try transcription again.")
            }
        )
        let retryStore = TranscriptInsightStore(acquisitionClient: retryClient)
        retryStore.send(.urlChanged("https://youtu.be/retry-current"))
        retryStore.send(.submit)
        let firstFailure = await waitFor {
            retryStore.phase == .transcriptFailed(message: "Try transcription again.")
        }
        expect(firstFailure, "Provider failure should be represented accurately")
        expect(retryStore.transcript == nil, "Provider failure must not expose an incorrect transcript")
        retryStore.send(.retry)
        expect(retryStore.phase == .checkingTranscript, "Retry should clear the obsolete error immediately")
        let secondFailure = await waitFor {
            retryStore.phase == .transcriptFailed(message: "Try transcription again.")
        }
        let retryCalls = await retryLog.values
        expect(secondFailure, "Retry failure should remain actionable")
        expect(
            retryCalls == [
                "acquire:https://youtu.be/retry-current",
                "acquire:https://youtu.be/retry-current",
            ],
            "Retry should reuse the current submitted URL"
        )

        if failures.isEmpty {
            print("Transcript Insight checks passed (\(supportedURLs.count + 11) scenarios).")
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
