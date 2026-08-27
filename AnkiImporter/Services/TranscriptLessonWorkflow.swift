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
        }
    }
}

@MainActor
final class TranscriptLessonWorkflow: ObservableObject {
    enum Phase: Equatable {
        case acquiring
        case reviewing
        case analyzing
        case ready
        case loadingHistory
        case failed
    }

    struct Snapshot: Equatable {
        var phase: Phase = .acquiring
        var transcript = ""
        var lesson: TranscriptLesson?
        var history: [TranscriptLessonSummary] = []
        var evaluatingExerciseIDs: Set<String> = []
        var errorMessage: String?
    }

    @Published private(set) var snapshot = Snapshot()

    private let analyzer: TranscriptLessonAnalyzing
    private let store: TranscriptLessonStoring

    init(analyzer: TranscriptLessonAnalyzing, store: TranscriptLessonStoring) {
        self.analyzer = analyzer
        self.store = store
    }

    convenience init() {
        self.init(
            analyzer: TranscriptLessonAgentClient(),
            store: SupabaseStore.shared
        )
    }

    func updateTranscript(_ transcript: String) {
        guard snapshot.phase != .analyzing else { return }
        snapshot.transcript = transcript
        snapshot.lesson = nil
        snapshot.phase = transcript.isEmpty ? .acquiring : .reviewing
        snapshot.errorMessage = nil
    }

    func reset() {
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
                sourceURL: nil,
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
