import Combine
import Foundation

@MainActor
protocol TranscriptLessonAnalyzing {
    func analyze(transcript: String) async throws -> TranscriptLessonAnalysis
    func evaluate(_ request: ExerciseEvaluationRequest) async throws -> ExerciseFeedback
}

@MainActor
protocol TranscriptLessonStoring {
    func saveLesson(_ lesson: TranscriptLesson) async throws -> TranscriptLesson
    func loadLessonSummaries() async throws -> [TranscriptLessonSummary]
    func loadLesson(id: Int64) async throws -> TranscriptLesson
    func saveAttempt(_ attempt: ExerciseAttempt, lessonID: Int64) async throws -> ExerciseAttempt
    func saveAnkiExport(noteID: Int64, itemID: String, lessonID: Int64) async throws
}

enum TranscriptLessonWorkflowError: LocalizedError, Equatable {
    case transcriptRequired
    case invalidOverview
    case invalidItemCount(Int)
    case duplicateItem(String)
    case invalidCategoryTags(String)
    case invalidTranscriptSpan(String)
    case invalidPracticeSet
    case lessonNotSaved
    case exerciseNotFound
    case answerRequired
    case sourceTooLong(Double)
    case sourceLanguageRequired
    case sourceNotEnglish(String)
    case itemNotFound
    case alreadyExported

    var errorDescription: String? {
        switch self {
        case .transcriptRequired:
            return "Paste or enter an English transcript before analyzing."
        case .invalidOverview:
            return "The Meaning Overview must contain a concise 3–5 sentence summary."
        case .invalidItemCount(let count):
            return "The analysis returned \(count) language items; a lesson needs 6–10 high-value items."
        case .duplicateItem(let expression):
            return "The analysis returned the same language item more than once: \(expression)."
        case .invalidCategoryTags(let expression):
            return "The category tags for \"\(expression)\" are duplicated or conflict with its primary category."
        case .invalidTranscriptSpan(let expression):
            return "The analysis could not connect \"\(expression)\" to the approved transcript."
        case .invalidPracticeSet:
            return "The analysis must provide recognition and production practice for 3–5 items."
        case .lessonNotSaved:
            return "Save the lesson before recording practice."
        case .exerciseNotFound:
            return "That exercise is no longer part of this lesson."
        case .answerRequired:
            return "Enter an answer before requesting feedback."
        case .sourceTooLong(let duration):
            return "This video is \(Int(duration.rounded())) seconds long. Transcript Lessons supports sources up to five minutes."
        case .sourceLanguageRequired:
            return "The source language could not be confirmed as English. Try an authorized local file or paste the transcript manually."
        case .sourceNotEnglish(let language):
            return "This source is primarily \(language), but Transcript Lessons currently supports primarily English sources."
        case .itemNotFound:
            return "That language item is no longer part of this lesson."
        case .alreadyExported:
            return "This language item has already been exported to Anki."
        }
    }
}

@MainActor
final class TranscriptLessonWorkflow: ObservableObject {
    enum Phase: Equatable {
        case sourceEntry
        case acquiring
        case transcribing
        case reviewing
        case analyzing
        case ready
        case loadingHistory
        case failed
    }

    struct Snapshot: Equatable {
        var phase: Phase = .sourceEntry
        var sourceURL = ""
        var source: VideoSource?
        var durationWarning: String?
        var acquisitionMethod: TranscriptAcquisitionMethod?
        var transcript = ""
        var lesson: TranscriptLesson?
        var history: [TranscriptLessonSummary] = []
        var evaluatingExerciseIDs: Set<String> = []
        var exportingItemIDs: Set<String> = []
        var failureStage: TranscriptAcquisitionStage?
        var canUseManualFallback = false
        var canRetryAcquisition = false
        var errorMessage: String?
    }

    @Published private(set) var snapshot = Snapshot()

    private let analyzer: TranscriptLessonAnalyzing
    private let store: TranscriptLessonStoring
    private let acquirer: TranscriptAcquiring
    private let ankiWriter: AnkiNoteWriting
    private var activeAcquisitionID: UUID?

    init(
        analyzer: TranscriptLessonAnalyzing,
        store: TranscriptLessonStoring,
        acquirer: TranscriptAcquiring = TranscriptAcquisitionAgentClient(),
        ankiWriter: AnkiNoteWriting = AnkiConnectClient.shared
    ) {
        self.analyzer = analyzer
        self.store = store
        self.acquirer = acquirer
        self.ankiWriter = ankiWriter
    }

    convenience init() {
        self.init(
            analyzer: TranscriptLessonAgentClient(),
            store: SupabaseStore.shared,
            acquirer: TranscriptAcquisitionAgentClient(),
            ankiWriter: AnkiConnectClient.shared
        )
    }

    func updateSourceURL(_ sourceURL: String) {
        guard snapshot.phase != .acquiring, snapshot.phase != .transcribing else { return }
        snapshot.sourceURL = sourceURL
        snapshot.source = nil
        snapshot.durationWarning = nil
        snapshot.errorMessage = nil
        snapshot.failureStage = nil
        snapshot.canRetryAcquisition = false
        activeAcquisitionID = nil
        snapshot.phase = .sourceEntry
    }

    func acquireFromSourceURL() async {
        let acquisitionID = UUID()
        activeAcquisitionID = acquisitionID
        do {
            let source = try TranscriptSourceURL.validate(snapshot.sourceURL)
            snapshot.sourceURL = source.canonicalURL
            snapshot.source = source
            snapshot.phase = .acquiring
            snapshot.errorMessage = nil
            snapshot.failureStage = nil
            snapshot.canUseManualFallback = false
            if let acquisition = try await acquirer.acquireCaptions(source: source) {
                guard activeAcquisitionID == acquisitionID else { return }
                try validateAndLoadForReview(acquisition)
            } else {
                guard activeAcquisitionID == acquisitionID else { return }
                snapshot.phase = .transcribing
                let acquisition = try await acquirer.transcribe(source: source)
                guard activeAcquisitionID == acquisitionID else { return }
                try validateAndLoadForReview(acquisition)
            }
        } catch is CancellationError {
            guard activeAcquisitionID == acquisitionID else { return }
            failAcquisition(
                with: TranscriptAcquisitionFailure(
                    stage: .acquisition,
                    message: "Cancelled. Temporary media cleanup was requested; you can retry or use a fallback.",
                    retryable: true
                )
            )
        } catch {
            guard activeAcquisitionID == acquisitionID else { return }
            failAcquisition(with: error)
        }
    }

    func transcribeLocalFile(_ url: URL) async {
        let acquisitionID = UUID()
        activeAcquisitionID = acquisitionID
        snapshot.phase = .transcribing
        snapshot.errorMessage = nil
        snapshot.failureStage = nil
        snapshot.canUseManualFallback = false
        do {
            let acquisition = try await acquirer.transcribe(localFile: url, source: snapshot.source)
            guard activeAcquisitionID == acquisitionID else { return }
            try validateAndLoadForReview(acquisition)
        } catch is CancellationError {
            guard activeAcquisitionID == acquisitionID else { return }
            failAcquisition(
                with: TranscriptAcquisitionFailure(
                    stage: .transcription,
                    message: "Cancelled. Temporary media cleanup was requested; you can retry or paste the transcript manually.",
                    retryable: true
                )
            )
        } catch {
            guard activeAcquisitionID == acquisitionID else { return }
            failAcquisition(with: error)
        }
    }

    func updateTranscript(_ transcript: String) {
        guard snapshot.phase != .analyzing else { return }
        snapshot.transcript = transcript
        snapshot.lesson = nil
        snapshot.phase = transcript.isEmpty ? .sourceEntry : .reviewing
        snapshot.acquisitionMethod = transcript.isEmpty ? nil : (snapshot.acquisitionMethod ?? .manual)
        snapshot.canUseManualFallback = false
        snapshot.failureStage = nil
        snapshot.canRetryAcquisition = false
        activeAcquisitionID = nil
        snapshot.errorMessage = nil
    }

    func reset() {
        activeAcquisitionID = nil
        snapshot = Snapshot()
    }

    func analyze() async {
        let approvedTranscript = snapshot.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !approvedTranscript.isEmpty else {
            fail(with: TranscriptLessonWorkflowError.transcriptRequired)
            return
        }

        snapshot.phase = .analyzing
        snapshot.errorMessage = nil

        do {
            let analysis = try await analyzer.analyze(transcript: approvedTranscript)
            try validate(analysis, transcript: approvedTranscript)

            let draft = TranscriptLesson(
                id: nil,
                createdAt: nil,
                sourceURL: snapshot.source?.canonicalURL,
                source: snapshot.source,
                approvedTranscript: approvedTranscript,
                overview: analysis.overview,
                items: analysis.items,
                exercises: analysis.exercises,
                attempts: []
            )
            let saved = try await store.saveLesson(draft)
            snapshot.transcript = approvedTranscript
            snapshot.lesson = saved
            snapshot.phase = .ready
        } catch {
            snapshot.failureStage = nil
            fail(with: error)
        }
    }

    func loadHistory() async {
        let previousPhase = snapshot.phase
        snapshot.phase = .loadingHistory
        snapshot.errorMessage = nil

        do {
            snapshot.history = try await store.loadLessonSummaries()
            snapshot.phase = previousPhase == .failed ? .reviewing : previousPhase
        } catch {
            fail(with: error)
        }
    }

    func openLesson(id: Int64) async {
        snapshot.phase = .loadingHistory
        snapshot.errorMessage = nil

        do {
            let lesson = try await store.loadLesson(id: id)
            snapshot.transcript = lesson.approvedTranscript
            snapshot.lesson = lesson
            snapshot.phase = .ready
        } catch {
            fail(with: error)
        }
    }

    func submitAnswer(exerciseID: String, answer: String) async {
        let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAnswer.isEmpty else {
            snapshot.errorMessage = TranscriptLessonWorkflowError.answerRequired.localizedDescription
            return
        }
        guard var lesson = snapshot.lesson, let lessonID = lesson.id else {
            snapshot.errorMessage = TranscriptLessonWorkflowError.lessonNotSaved.localizedDescription
            return
        }
        guard let exercise = lesson.exercises.first(where: { $0.id == exerciseID }),
              let item = lesson.items.first(where: { $0.id == exercise.itemID }) else {
            snapshot.errorMessage = TranscriptLessonWorkflowError.exerciseNotFound.localizedDescription
            return
        }

        snapshot.evaluatingExerciseIDs.insert(exerciseID)
        snapshot.errorMessage = nil
        defer { snapshot.evaluatingExerciseIDs.remove(exerciseID) }

        do {
            let feedback = try await analyzer.evaluate(
                ExerciseEvaluationRequest(
                    transcript: lesson.approvedTranscript,
                    item: item,
                    exercise: exercise,
                    answer: trimmedAnswer
                )
            )
            let savedAttempt = try await store.saveAttempt(
                ExerciseAttempt(
                    id: nil,
                    exerciseID: exerciseID,
                    answer: trimmedAnswer,
                    feedback: feedback,
                    createdAt: nil
                ),
                lessonID: lessonID
            )
            lesson.attempts.append(savedAttempt)
            snapshot.lesson = lesson
        } catch {
            snapshot.errorMessage = error.localizedDescription
        }
    }

    func exportToAnki(itemID: String) async {
        guard var lesson = snapshot.lesson, let lessonID = lesson.id else {
            snapshot.errorMessage = TranscriptLessonWorkflowError.lessonNotSaved.localizedDescription
            return
        }
        guard let index = lesson.items.firstIndex(where: { $0.id == itemID }) else {
            snapshot.errorMessage = TranscriptLessonWorkflowError.itemNotFound.localizedDescription
            return
        }
        guard lesson.items[index].ankiNoteID == nil else {
            snapshot.errorMessage = TranscriptLessonWorkflowError.alreadyExported.localizedDescription
            return
        }
        guard !snapshot.exportingItemIDs.contains(itemID) else { return }

        snapshot.exportingItemIDs.insert(itemID)
        snapshot.errorMessage = nil
        defer { snapshot.exportingItemIDs.remove(itemID) }
        do {
            let note = AnkiNoteMapping.naturalEnglish(
                item: lesson.items[index],
                sourceURL: lesson.sourceURL,
                deduplicationTag: ankiDeduplicationTag(lessonID: lessonID, itemID: itemID)
            )
            let noteID = try await ankiWriter.write(note)
            do {
                try await store.saveAnkiExport(noteID: noteID, itemID: itemID, lessonID: lessonID)
                lesson.items[index].ankiNoteID = noteID
                snapshot.lesson = lesson
            } catch {
                snapshot.errorMessage = "Anki created note \(noteID), but its export state could not be saved: \(error.localizedDescription)"
            }
        } catch {
            snapshot.errorMessage = error.localizedDescription
        }
    }

    private func validateAndLoadForReview(_ acquisition: TranscriptAcquisition) throws {
        let transcript = acquisition.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else {
            throw TranscriptAcquisitionFailure(
                stage: .transcription,
                message: "No speech was found. Try another file or paste the transcript manually.",
                retryable: true
            )
        }
        if let duration = acquisition.durationSeconds ?? acquisition.source?.durationSeconds {
            guard duration <= 300 else {
                throw TranscriptLessonWorkflowError.sourceTooLong(duration)
            }
            snapshot.durationWarning = duration > 180
                ? "This source is longer than three minutes. The lesson may be denser than usual."
                : nil
        }
        guard let language = (acquisition.detectedLanguage ?? acquisition.source?.primaryLanguage)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !language.isEmpty else {
            throw TranscriptLessonWorkflowError.sourceLanguageRequired
        }
        let normalizedLanguage = language.lowercased()
        guard normalizedLanguage == "en" || normalizedLanguage.hasPrefix("en-") || normalizedLanguage == "english" else {
            throw TranscriptLessonWorkflowError.sourceNotEnglish(language)
        }

        snapshot.source = acquisition.source ?? snapshot.source
        snapshot.sourceURL = snapshot.source?.canonicalURL ?? snapshot.sourceURL
        snapshot.transcript = transcript
        snapshot.lesson = nil
        snapshot.acquisitionMethod = acquisition.method
        snapshot.phase = .reviewing
        snapshot.errorMessage = nil
        snapshot.failureStage = nil
        snapshot.canUseManualFallback = false
        snapshot.canRetryAcquisition = false
        activeAcquisitionID = nil
    }

    private func failAcquisition(with error: Error) {
        if let failure = error as? TranscriptAcquisitionFailure {
            snapshot.failureStage = failure.stage
            snapshot.canRetryAcquisition = failure.retryable
        } else if error is TranscriptSourceURLError || error is TranscriptLessonWorkflowError {
            snapshot.failureStage = .acquisition
            snapshot.canRetryAcquisition = false
        } else {
            snapshot.failureStage = .acquisition
            snapshot.canRetryAcquisition = true
        }
        snapshot.canUseManualFallback = true
        fail(with: error)
    }

    private func ankiDeduplicationTag(lessonID: Int64, itemID: String) -> String {
        let exactItemID = itemID.utf8.map { String(format: "%02x", $0) }.joined()
        return "anki_mate_transcript_\(lessonID)_\(exactItemID)"
    }

    private func validate(_ analysis: TranscriptLessonAnalysis, transcript: String) throws {
        guard (3...5).contains(analysis.overview.summary.count),
              !analysis.overview.mainPoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !analysis.overview.toneAndRegister.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscriptLessonWorkflowError.invalidOverview
        }
        guard (6...10).contains(analysis.items.count) else {
            throw TranscriptLessonWorkflowError.invalidItemCount(analysis.items.count)
        }

        var itemIDs = Set<String>()
        var expressions = Set<String>()
        for item in analysis.items {
            guard itemIDs.insert(item.id).inserted else {
                throw TranscriptLessonWorkflowError.duplicateItem(item.expression)
            }
            let normalizedExpression = item.expression.lowercased()
            guard expressions.insert(normalizedExpression).inserted else {
                throw TranscriptLessonWorkflowError.duplicateItem(item.expression)
            }
            let secondary = Set(item.secondaryCategories)
            guard secondary.count == item.secondaryCategories.count,
                  !secondary.contains(item.primaryCategory) else {
                throw TranscriptLessonWorkflowError.invalidCategoryTags(item.expression)
            }
            guard transcript.substring(utf16Start: item.spanStart, utf16End: item.spanEnd) == item.expression else {
                throw TranscriptLessonWorkflowError.invalidTranscriptSpan(item.expression)
            }
        }

        let grouped = Dictionary(grouping: analysis.exercises, by: \.itemID)
        guard (3...5).contains(grouped.count) else {
            throw TranscriptLessonWorkflowError.invalidPracticeSet
        }
        guard Set(analysis.exercises.map(\.id)).count == analysis.exercises.count else {
            throw TranscriptLessonWorkflowError.invalidPracticeSet
        }
        let knownIDs = Set(analysis.items.map(\.id))
        for (itemID, exercises) in grouped {
            guard knownIDs.contains(itemID),
                  exercises.filter({ $0.kind == .recognition }).count == 1,
                  exercises.filter({ $0.kind == .production }).count == 1,
                  exercises.first(where: { $0.kind == .recognition })?.expectedAnswer?.isEmpty == false,
                  exercises.first(where: { $0.kind == .recognition })?.explanation?.isEmpty == false else {
                throw TranscriptLessonWorkflowError.invalidPracticeSet
            }
        }
        let practicedItems = analysis.items.filter { $0.practicePriority != nil }
        let priorities = Set(practicedItems.compactMap(\.practicePriority))
        guard Set(practicedItems.map(\.id)) == Set(grouped.keys),
              priorities == Set(1...grouped.count) else {
            throw TranscriptLessonWorkflowError.invalidPracticeSet
        }
    }

    private func fail(with error: Error) {
        snapshot.phase = .failed
        snapshot.errorMessage = error.localizedDescription
    }
}

private extension String {
    func substring(utf16Start: Int, utf16End: Int) -> String? {
        guard utf16Start >= 0, utf16End >= utf16Start,
              let startOffset = utf16.index(utf16.startIndex, offsetBy: utf16Start, limitedBy: utf16.endIndex),
              let endOffset = utf16.index(utf16.startIndex, offsetBy: utf16End, limitedBy: utf16.endIndex),
              let start = String.Index(startOffset, within: self),
              let end = String.Index(endOffset, within: self) else {
            return nil
        }
        return String(self[start..<end])
    }
}
