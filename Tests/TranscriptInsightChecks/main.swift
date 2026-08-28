import Foundation
import TranscriptInsightCore

@main
struct TranscriptInsightChecks {
    @MainActor
    static func main() {
        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
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

        if failures.isEmpty {
            print("Transcript Insight checks passed (\(supportedURLs.count + 5) scenarios).")
        } else {
            for failure in failures { fputs("FAIL: \(failure)\n", stderr) }
            exit(1)
        }
    }
}
