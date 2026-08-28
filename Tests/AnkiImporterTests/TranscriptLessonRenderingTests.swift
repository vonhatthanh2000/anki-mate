import AppKit
import SwiftUI
import Testing
@testable import AnkiImporter

@MainActor
@Suite(.serialized)
struct TranscriptLessonRenderingTests {
    @Test
    func representativeWorkflowStatesRenderAtTheApplicationSeam() async throws {
        let analyzer = RenderingAnalyzer()
        let store = RenderingStore()
        let acquirer = RenderingAcquirer()
        let writer = RenderingWriter()
        let workflow = TranscriptLessonWorkflow(
            analyzer: analyzer,
            store: store,
            acquirer: acquirer,
            ankiWriter: writer
        )
        let selectedFeature = Binding<String?>.constant("transcript-lessons")

        let sourceEntryView = TranscriptLessonView(
            selectedFeature: selectedFeature,
            workflow: workflow
        )
        let sourceEntry = render(sourceEntryView)
        #expect(sourceEntry.size == canvasSize)
        let sourceControls = accessibilityControls(in: sourceEntryView)
        #expect(sourceControls.keys.contains { $0.contains("Back to Home") })
        #expect(sourceControls["Saved lessons"] == true)
        #expect(sourceControls["New lesson"] == true)
        #expect(sourceControls["Get transcript"] == false)
        #expect(sourceControls["Choose local file…"] == true)
        #expect(sourceControls["Analyze transcript"] == false)

        workflow.updateSourceURL("https://www.youtube.com/watch?v=render")
        let sourceWithURL = TranscriptLessonView(
            selectedFeature: selectedFeature,
            workflow: workflow
        )
        #expect(accessibilityControls(in: sourceWithURL)["Get transcript"] == true)

        workflow.updateTranscript("Learner-approved manual transcript.")
        let sourceWithTranscript = TranscriptLessonView(
            selectedFeature: selectedFeature,
            workflow: workflow
        )
        #expect(accessibilityControls(in: sourceWithTranscript)["Analyze transcript"] == true)

        workflow.reset()
        workflow.updateSourceURL("https://www.youtube.com/watch?v=render")
        acquirer.suspendAcquisition = true
        let acquisition = Task { await workflow.acquireFromSourceURL() }
        for _ in 0..<20 where workflow.snapshot.phase != .acquiring {
            await Task.yield()
        }
        #expect(workflow.snapshot.phase == .acquiring)
        let processingView = TranscriptLessonView(
            selectedFeature: selectedFeature,
            workflow: workflow
        )
        let processing = render(processingView)
        #expect(processing.size == canvasSize)
        #expect(accessibilityControls(in: processingView)["Cancel"] == true)
        acquisition.cancel()
        _ = await acquisition.value

        let lessonReadyView = TranscriptLessonResultView(workflow: workflow, lesson: Self.lesson)
        let lessonReady = render(lessonReadyView)
        #expect(lessonReady.size == canvasSize)
        let lessonControls = accessibilityControls(in: lessonReadyView)
        #expect(lessonControls["Open original source for replay and shadowing"] == true)
        #expect(lessonControls["Add to Anki"] == true)
        #expect(lessonControls["Check answer"] == false)

        store.summaries = [
            TranscriptLessonSummary(
                id: 42,
                createdAt: "2026-08-28T00:00:00Z",
                sourceURL: Self.lesson.sourceURL,
                mainPoint: Self.lesson.overview.mainPoint,
                itemCount: Self.lesson.items.count
            )
        ]
        await workflow.loadHistory()
        let historyView = TranscriptLessonHistoryView(
            workflow: workflow,
            isPresented: .constant(true)
        )
        let history = render(historyView)
        #expect(history.size == canvasSize)
        #expect(accessibilityControls(in: historyView)["Done"] == true)
    }

    @Test
    func actionStyleKeepsGeometryWhenDisabledOrShowingACompletedState() throws {
        let enabled = renderControl(label: "Analyze transcript", isEnabled: true)
        let disabled = renderControl(label: "Analyze transcript", isEnabled: false)
        #expect(enabled.size == disabled.size)
        #expect(enabled.tiffRepresentation != disabled.tiffRepresentation)

        let exporting = renderControl(label: "Exporting…", minimumWidth: 160)
        let exported = renderControl(label: "Exported to Anki", minimumWidth: 160)
        #expect(exporting.size == exported.size)
    }

    @Test
    func lightSurfacesAndPrimaryActionsKeepReadableSemanticContrast() throws {
        #expect(contrast(NSColor(AppTheme.text), NSColor(AppTheme.editField)) >= 4.5)
        #expect(contrast(.white, NSColor(AppTheme.actionPrimary)) >= 4.5)
        #expect(contrast(.white, NSColor(AppTheme.actionSecondary)) >= 4.5)
    }

    private static let canvasSize = NSSize(width: 1_200, height: 800)

    private func render<Content: View>(_ content: Content) -> NSImage {
        let renderer = ImageRenderer(
            content: content.frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        )
        renderer.proposedSize = ProposedViewSize(Self.canvasSize)
        return renderer.nsImage!
    }

    private func renderControl(
        label: String,
        isEnabled: Bool = true,
        minimumWidth: CGFloat? = nil
    ) -> NSImage {
        let renderer = ImageRenderer(
            content: Button(action: {}) {
                Text(label).frame(minWidth: minimumWidth)
            }
            .buttonStyle(TranscriptLessonButtonStyle())
            .disabled(!isEnabled)
            .fixedSize()
        )
        return renderer.nsImage!
    }

    private func accessibilityControls<Content: View>(in content: Content) -> [String: Bool] {
        let hostingView = NSHostingView(
            rootView: content.frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        )
        hostingView.frame.size = Self.canvasSize
        hostingView.layoutSubtreeIfNeeded()
        return accessibilityControls(in: hostingView)
    }

    private func accessibilityControls(in element: Any) -> [String: Bool] {
        guard let accessible = element as? NSObject else { return [:] }
        var controls: [String: Bool] = [:]
        let role = String(describing: accessible.value(forKey: "accessibilityRole"))
        if let label = accessible.value(forKey: "accessibilityLabel") as? String,
           role.contains("Button") || role.contains("Link") {
            controls[label] = accessible.value(forKey: "accessibilityEnabled") as? Bool ?? true
        }
        for child in accessible.value(forKey: "accessibilityChildren") as? [Any] ?? [] {
            controls.merge(accessibilityControls(in: child)) { _, new in new }
        }
        return controls
    }

    private func contrast(_ foreground: NSColor, _ background: NSColor) -> Double {
        let foregroundLuminance = luminance(foreground)
        let backgroundLuminance = luminance(background)
        return (max(foregroundLuminance, backgroundLuminance) + 0.05)
            / (min(foregroundLuminance, backgroundLuminance) + 0.05)
    }

    private func luminance(_ color: NSColor) -> Double {
        let rgb = color.usingColorSpace(.sRGB)!
        return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
            .map { component in
                let value = Double(component)
                return value <= 0.03928
                    ? value / 12.92
                    : pow((value + 0.055) / 1.055, 2.4)
            }
            .enumerated()
            .reduce(0) { result, entry in
                result + entry.element * [0.2126, 0.7152, 0.0722][entry.offset]
            }
    }

    private static let lesson: TranscriptLesson = {
        let transcript = "The speaker followed through."
        let item = TranscriptLanguageItem(
            id: "item-1",
            expression: "followed through",
            spanStart: 12,
            spanEnd: 28,
            sourceExcerpt: "followed through",
            primaryCategory: .phrasalVerb,
            secondaryCategories: [],
            meaningAndUsage: "Completed an intended action.",
            cefrEstimate: "B2",
            selectionRationale: "Reusable natural English.",
            naturalExample: "She followed through on the plan.",
            vietnameseGloss: nil,
            practicePriority: 1
        )
        return TranscriptLesson(
            id: 42,
            createdAt: "2026-08-28T00:00:00Z",
            sourceURL: "https://www.youtube.com/watch?v=render",
            approvedTranscript: transcript,
            overview: MeaningOverview(
                summary: ["The speaker completed a plan."],
                mainPoint: "Follow-through matters.",
                supportingIdeas: [],
                toneAndRegister: "Encouraging",
                contextNotes: []
            ),
            items: [item],
            exercises: [
                LessonExercise(
                    id: "exercise-1",
                    itemID: item.id,
                    kind: .production,
                    prompt: "Use the expression naturally.",
                    expectedAnswer: nil,
                    explanation: nil
                )
            ],
            attempts: []
        )
    }()
}

@MainActor
private final class RenderingAnalyzer: TranscriptLessonAnalyzing {
    func analyze(transcript: String) async throws -> TranscriptLessonAnalysis {
        fatalError("Analysis is not used by rendering tests")
    }

    func evaluate(_ request: ExerciseEvaluationRequest) async throws -> ExerciseFeedback {
        fatalError("Evaluation is not used by rendering tests")
    }
}

@MainActor
private final class RenderingStore: TranscriptLessonStoring {
    var summaries: [TranscriptLessonSummary] = []
    func saveLesson(_ lesson: TranscriptLesson) async throws -> TranscriptLesson { lesson }
    func loadLessonSummaries() async throws -> [TranscriptLessonSummary] { summaries }
    func loadLesson(id: Int64) async throws -> TranscriptLesson { fatalError("Not used") }
    func saveAttempt(_ attempt: ExerciseAttempt, lessonID: Int64) async throws -> ExerciseAttempt { attempt }
    func saveAnkiExport(noteID: Int64, itemID: String, lessonID: Int64) async throws {}
}

@MainActor
private final class RenderingAcquirer: TranscriptAcquiring {
    var suspendAcquisition = false
    func acquireCaptions(source: VideoSource) async throws -> TranscriptAcquisition? {
        if suspendAcquisition {
            try await Task.sleep(for: .seconds(30))
        }
        return nil
    }

    func transcribe(source: VideoSource) async throws -> TranscriptAcquisition {
        throw CancellationError()
    }

    func transcribe(localFile: URL, source: VideoSource?) async throws -> TranscriptAcquisition {
        throw CancellationError()
    }
}

@MainActor
private final class RenderingWriter: AnkiNoteWriting {
    func write(_ note: AnkiNote) async throws -> Int64 { 1 }
}
