import Testing
@testable import AnkiImporter

@MainActor
@Suite
struct TranscriptLessonWorkflowTests {
    @Test
    func testAnalysisWaitsForExplicitActionAndSavesApprovedTranscript() async throws {
        let fixture = LessonFixtures.analysis()
        let analyzer = AnalyzerFake(analysis: fixture)
        let store = StoreFake()
        let workflow = TranscriptLessonWorkflow(analyzer: analyzer, store: store)

        workflow.updateTranscript(LessonFixtures.transcript)

        #expect(analyzer.analyzeCalls == [])
        #expect(workflow.snapshot.phase == .reviewing)

        await workflow.analyze()

        #expect(analyzer.analyzeCalls == [LessonFixtures.transcript])
        #expect(store.savedLessons.first?.approvedTranscript == LessonFixtures.transcript)
        #expect(workflow.snapshot.phase == .ready)
        #expect(workflow.snapshot.lesson?.id == 42)
        #expect(workflow.snapshot.lesson?.items.count == 6)
        #expect(store.savedLessons.first?.overview == fixture.overview)
        #expect(store.savedLessons.first?.items == fixture.items)
        #expect(store.savedLessons.first?.exercises == fixture.exercises)
    }

    @Test
    func testAnalysisRejectsAnItemThatDoesNotResolveToTheApprovedTranscript() async {
        var items = LessonFixtures.analysis().items
        let invalid = items[0]
        items[0] = TranscriptLanguageItem(
            id: invalid.id,
            expression: invalid.expression,
            spanStart: invalid.spanStart + 1,
            spanEnd: invalid.spanEnd + 1,
            sourceExcerpt: invalid.sourceExcerpt,
            primaryCategory: invalid.primaryCategory,
            secondaryCategories: invalid.secondaryCategories,
            meaningAndUsage: invalid.meaningAndUsage,
            cefrEstimate: invalid.cefrEstimate,
            selectionRationale: invalid.selectionRationale,
            naturalExample: invalid.naturalExample,
            vietnameseGloss: invalid.vietnameseGloss,
            practicePriority: invalid.practicePriority
        )
        let base = LessonFixtures.analysis()
        let analyzer = AnalyzerFake(
            analysis: TranscriptLessonAnalysis(
                overview: base.overview,
                items: items,
                exercises: base.exercises
            )
        )
        let store = StoreFake()
        let workflow = TranscriptLessonWorkflow(analyzer: analyzer, store: store)
        workflow.updateTranscript(LessonFixtures.transcript)

        await workflow.analyze()

        #expect(workflow.snapshot.phase == .failed)
        #expect(store.savedLessons.isEmpty)
        #expect(workflow.snapshot.errorMessage?.contains("approved transcript") == true)
    }

    @Test
    func testAnalysisAcceptsUtf16SpansAfterEmoji() async {
        let prefix = "🔬 "
        let transcript = prefix + LessonFixtures.transcript
        let base = LessonFixtures.analysis()
        let offset = prefix.utf16.count
        let shiftedItems = base.items.map { item in
            TranscriptLanguageItem(
                id: item.id,
                expression: item.expression,
                spanStart: item.spanStart + offset,
                spanEnd: item.spanEnd + offset,
                sourceExcerpt: item.sourceExcerpt,
                primaryCategory: item.primaryCategory,
                secondaryCategories: item.secondaryCategories,
                meaningAndUsage: item.meaningAndUsage,
                cefrEstimate: item.cefrEstimate,
                selectionRationale: item.selectionRationale,
                naturalExample: item.naturalExample,
                vietnameseGloss: item.vietnameseGloss,
                practicePriority: item.practicePriority
            )
        }
        let store = StoreFake()
        let workflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(
                analysis: TranscriptLessonAnalysis(
                    overview: base.overview,
                    items: shiftedItems,
                    exercises: base.exercises
                )
            ),
            store: store
        )
        workflow.updateTranscript(transcript)

        await workflow.analyze()

        #expect(workflow.snapshot.phase == .ready)
        #expect(store.savedLessons.first?.approvedTranscript == transcript)
    }

    @Test
    func testAnalysisRejectsTooFewOrDuplicateItems() async {
        let base = LessonFixtures.analysis()
        let store = StoreFake()
        let tooFew = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(
                analysis: TranscriptLessonAnalysis(
                    overview: base.overview,
                    items: Array(base.items.prefix(5)),
                    exercises: base.exercises
                )
            ),
            store: store
        )
        tooFew.updateTranscript(LessonFixtures.transcript)

        await tooFew.analyze()

        #expect(tooFew.snapshot.errorMessage?.contains("6–10") == true)
        #expect(store.savedLessons.isEmpty)

        let duplicate = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(
                analysis: TranscriptLessonAnalysis(
                    overview: base.overview,
                    items: base.items + [base.items[0]],
                    exercises: base.exercises
                )
            ),
            store: store
        )
        duplicate.updateTranscript(LessonFixtures.transcript)

        await duplicate.analyze()

        #expect(duplicate.snapshot.errorMessage?.contains("same language item") == true)
        #expect(store.savedLessons.isEmpty)
    }

    @Test
    func testAnalysisRejectsConflictingCategoriesAndPracticePriorities() async {
        let base = LessonFixtures.analysis()
        let first = base.items[0]
        var invalidCategories = base.items
        invalidCategories[0] = LessonFixtures.copy(
            first,
            secondaryCategories: [first.primaryCategory]
        )
        let categoryWorkflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(
                analysis: TranscriptLessonAnalysis(
                    overview: base.overview,
                    items: invalidCategories,
                    exercises: base.exercises
                )
            ),
            store: StoreFake()
        )
        categoryWorkflow.updateTranscript(LessonFixtures.transcript)

        await categoryWorkflow.analyze()

        #expect(categoryWorkflow.snapshot.errorMessage?.contains("category tags") == true)

        var invalidPriorities = base.items
        invalidPriorities[0] = LessonFixtures.copy(first, practicePriority: 2)
        let practiceWorkflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(
                analysis: TranscriptLessonAnalysis(
                    overview: base.overview,
                    items: invalidPriorities,
                    exercises: base.exercises
                )
            ),
            store: StoreFake()
        )
        practiceWorkflow.updateTranscript(LessonFixtures.transcript)

        await practiceWorkflow.analyze()

        #expect(practiceWorkflow.snapshot.errorMessage?.contains("recognition and production") == true)
    }

    @Test
    func testHistoryCanBeLoadedAndACompleteLessonReopened() async throws {
        let analyzer = AnalyzerFake(analysis: LessonFixtures.analysis())
        let store = StoreFake()
        var saved = store.makeSavedLesson()
        saved.attempts = [
            ExerciseAttempt(
                id: 7,
                exerciseID: "item-1-production",
                answer: "A saved answer",
                feedback: AnalyzerFake.feedback,
                createdAt: "2026-08-27T01:00:00Z"
            )
        ]
        store.lessonsByID[42] = saved
        store.summaries = [
            TranscriptLessonSummary(
                id: 42,
                createdAt: "2026-08-27T00:00:00Z",
                sourceURL: nil,
                mainPoint: saved.overview.mainPoint,
                itemCount: saved.items.count
            )
        ]
        let workflow = TranscriptLessonWorkflow(analyzer: analyzer, store: store)

        await workflow.loadHistory()
        #expect(workflow.snapshot.history.map(\.id) == [42])

        await workflow.openLesson(id: 42)
        #expect(workflow.snapshot.phase == .ready)
        #expect(workflow.snapshot.lesson == saved)
        #expect(workflow.snapshot.transcript == LessonFixtures.transcript)
        #expect(workflow.snapshot.lesson?.attempts.first?.answer == "A saved answer")
    }

    @Test
    func testProductionAnswerReceivesAndPersistsNaturalnessFeedback() async throws {
        let analyzer = AnalyzerFake(analysis: LessonFixtures.analysis())
        let store = StoreFake()
        store.lessonsByID[42] = store.makeSavedLesson()
        let workflow = TranscriptLessonWorkflow(analyzer: analyzer, store: store)
        await workflow.openLesson(id: 42)

        await workflow.submitAnswer(
            exerciseID: "item-1-production",
            answer: "I had to take the broader context into account."
        )

        #expect(analyzer.evaluationRequests.count == 1)
        #expect(store.savedAttempts.count == 1)
        #expect(workflow.snapshot.lesson?.attempts.count == 1)
        #expect(workflow.snapshot.lesson?.attempts.first?.feedback.naturalRevision == AnalyzerFake.feedback.naturalRevision)
        #expect(workflow.snapshot.lesson?.attempts.first?.feedback == AnalyzerFake.feedback)
    }

    @Test
    func testRecognitionAnswerIsEvaluatedAndPersisted() async {
        let analyzer = AnalyzerFake(analysis: LessonFixtures.analysis())
        let store = StoreFake()
        store.lessonsByID[42] = store.makeSavedLesson()
        let workflow = TranscriptLessonWorkflow(analyzer: analyzer, store: store)
        await workflow.openLesson(id: 42)

        await workflow.submitAnswer(
            exerciseID: "item-1-recognition",
            answer: "It introduces a contrast despite limited evidence."
        )

        #expect(analyzer.evaluationRequests.first?.exercise.kind == .recognition)
        #expect(store.savedAttempts.first?.exerciseID == "item-1-recognition")
        #expect(store.savedAttempts.first?.feedback.meaningFeedback == AnalyzerFake.feedback.meaningFeedback)
    }
}

@MainActor
private final class AnalyzerFake: TranscriptLessonAnalyzing {
    static let feedback = ExerciseFeedback(
        isCorrect: true,
        meaningFeedback: "The intended meaning is clear.",
        correctnessFeedback: "The sentence is grammatically correct.",
        appropriatenessFeedback: "The expression fits the context.",
        naturalnessFeedback: "This sounds natural.",
        explanation: "You used the collocation accurately.",
        naturalRevision: "I had to take the broader context into account."
    )

    let analysis: TranscriptLessonAnalysis
    var analyzeCalls: [String] = []
    var evaluationRequests: [ExerciseEvaluationRequest] = []

    init(analysis: TranscriptLessonAnalysis) {
        self.analysis = analysis
    }

    func analyze(transcript: String) async throws -> TranscriptLessonAnalysis {
        analyzeCalls.append(transcript)
        return analysis
    }

    func evaluate(_ request: ExerciseEvaluationRequest) async throws -> ExerciseFeedback {
        evaluationRequests.append(request)
        return Self.feedback
    }
}

@MainActor
private final class StoreFake: TranscriptLessonStoring {
    var savedLessons: [TranscriptLesson] = []
    var summaries: [TranscriptLessonSummary] = []
    var lessonsByID: [Int64: TranscriptLesson] = [:]
    var savedAttempts: [ExerciseAttempt] = []

    func saveLesson(_ lesson: TranscriptLesson) async throws -> TranscriptLesson {
        savedLessons.append(lesson)
        var saved = lesson
        saved.id = 42
        saved.createdAt = "2026-08-27T00:00:00Z"
        lessonsByID[42] = saved
        return saved
    }

    func loadLessonSummaries() async throws -> [TranscriptLessonSummary] {
        summaries
    }

    func loadLesson(id: Int64) async throws -> TranscriptLesson {
        guard let lesson = lessonsByID[id] else {
            throw StoreFakeError.lessonNotFound
        }
        return lesson
    }

    func saveAttempt(_ attempt: ExerciseAttempt, lessonID: Int64) async throws -> ExerciseAttempt {
        var saved = attempt
        saved.id = Int64(savedAttempts.count + 1)
        saved.createdAt = "2026-08-27T00:00:00Z"
        savedAttempts.append(saved)
        return saved
    }

    func makeSavedLesson() -> TranscriptLesson {
        let analysis = LessonFixtures.analysis()
        return TranscriptLesson(
            id: 42,
            createdAt: "2026-08-27T00:00:00Z",
            sourceURL: nil,
            approvedTranscript: LessonFixtures.transcript,
            overview: analysis.overview,
            items: analysis.items,
            exercises: analysis.exercises,
            attempts: []
        )
    }
}

private enum StoreFakeError: Error {
    case lessonNotFound
}

private enum LessonFixtures {
    static let transcript = "Although the evidence was limited, Maya took the broader context into account, ruled out a quick fix, followed through on the experiment, came across an unexpected pattern, and ended up changing course."

    static func analysis() -> TranscriptLessonAnalysis {
        let expressions: [(String, LanguageCategory)] = [
            ("Although the evidence was limited", .grammarPattern),
            ("took the broader context into account", .collocation),
            ("ruled out", .phrasalVerb),
            ("followed through", .phrasalVerb),
            ("came across", .phrasalVerb),
            ("ended up", .phrasalVerb)
        ]
        let items = expressions.enumerated().map { index, entry in
            let range = transcript.range(of: entry.0)!
            let start = range.lowerBound.utf16Offset(in: transcript)
            let end = range.upperBound.utf16Offset(in: transcript)
            return TranscriptLanguageItem(
                id: "item-\(index + 1)",
                expression: entry.0,
                spanStart: start,
                spanEnd: end,
                sourceExcerpt: entry.0,
                primaryCategory: entry.1,
                secondaryCategories: [],
                meaningAndUsage: "A concise contextual explanation.",
                cefrEstimate: "B2",
                selectionRationale: "It is useful for understanding and reuse.",
                naturalExample: "This is a natural new example.",
                vietnameseGloss: index == 0 ? "Mặc dù bằng chứng còn hạn chế" : nil,
                practicePriority: index < 3 ? index + 1 : nil
            )
        }
        let exercises = items.prefix(3).flatMap { item in
            [
                LessonExercise(
                    id: "\(item.id)-recognition",
                    itemID: item.id,
                    kind: .recognition,
                    prompt: "Choose the meaning that fits the context.",
                    expectedAnswer: "The contextual meaning.",
                    explanation: "The source context makes this meaning appropriate."
                ),
                LessonExercise(
                    id: "\(item.id)-production",
                    itemID: item.id,
                    kind: .production,
                    prompt: "Write a new sentence using \(item.expression).",
                    expectedAnswer: nil,
                    explanation: nil
                )
            ]
        }
        return TranscriptLessonAnalysis(
            overview: MeaningOverview(
                summary: [
                    "Maya examined limited evidence.",
                    "She continued the experiment and changed direction after noticing a pattern.",
                    "The passage emphasizes careful, flexible reasoning."
                ],
                mainPoint: "Careful investigation can justify changing course.",
                supportingIdeas: ["Consider context", "Test assumptions", "Respond to evidence"],
                toneAndRegister: "Reflective and explanatory",
                contextNotes: []
            ),
            items: items,
            exercises: exercises
        )
    }

    static func copy(
        _ item: TranscriptLanguageItem,
        secondaryCategories: [LanguageCategory]? = nil,
        practicePriority: Int? = nil
    ) -> TranscriptLanguageItem {
        TranscriptLanguageItem(
            id: item.id,
            expression: item.expression,
            spanStart: item.spanStart,
            spanEnd: item.spanEnd,
            sourceExcerpt: item.sourceExcerpt,
            primaryCategory: item.primaryCategory,
            secondaryCategories: secondaryCategories ?? item.secondaryCategories,
            meaningAndUsage: item.meaningAndUsage,
            cefrEstimate: item.cefrEstimate,
            selectionRationale: item.selectionRationale,
            naturalExample: item.naturalExample,
            vietnameseGloss: item.vietnameseGloss,
            practicePriority: practicePriority ?? item.practicePriority
        )
    }
}
