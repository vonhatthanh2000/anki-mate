import Foundation
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
    func testAnalysisAcceptsFewerItemsButStillRejectsDuplicates() async {
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

        #expect(tooFew.snapshot.phase == .ready)
        #expect(store.savedLessons.first?.items.count == 5)

        let duplicateStore = StoreFake()
        let duplicate = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(
                analysis: TranscriptLessonAnalysis(
                    overview: base.overview,
                    items: base.items + [base.items[0]],
                    exercises: base.exercises
                )
            ),
            store: duplicateStore
        )
        duplicate.updateTranscript(LessonFixtures.transcript)

        await duplicate.analyze()

        #expect(duplicate.snapshot.errorMessage?.contains("same language item") == true)
        #expect(duplicateStore.savedLessons.isEmpty)
    }

    @Test
    func testMeaningOverviewLimitsAndSpeakerAttributionArePersisted() async {
        let base = LessonFixtures.analysis()
        let invalidOverview = MeaningOverview(
            summary: ["Too short.", "Only two sentences."],
            mainPoint: base.overview.mainPoint,
            supportingIdeas: base.overview.supportingIdeas,
            toneAndRegister: base.overview.toneAndRegister,
            contextNotes: []
        )
        let shortOverviewStore = StoreFake()
        let invalidWorkflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(
                analysis: TranscriptLessonAnalysis(
                    overview: invalidOverview,
                    items: base.items,
                    exercises: base.exercises
                )
            ),
            store: shortOverviewStore
        )
        invalidWorkflow.updateTranscript(LessonFixtures.transcript)

        await invalidWorkflow.analyze()

        #expect(invalidWorkflow.snapshot.phase == .ready)
        #expect(shortOverviewStore.savedLessons.first?.overview == invalidOverview)

        let attributedOverview = MeaningOverview(
            summary: [
                "The speaker says the evidence was limited.",
                "According to the speaker, the experiment revealed an unexpected pattern.",
                "She explains that this led Maya to change course."
            ],
            mainPoint: base.overview.mainPoint,
            supportingIdeas: base.overview.supportingIdeas,
            toneAndRegister: base.overview.toneAndRegister,
            contextNotes: []
        )
        let store = StoreFake()
        let attributedWorkflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(
                analysis: TranscriptLessonAnalysis(
                    overview: attributedOverview,
                    items: base.items,
                    exercises: base.exercises
                )
            ),
            store: store
        )
        attributedWorkflow.updateTranscript(LessonFixtures.transcript)

        await attributedWorkflow.analyze()

        #expect(store.savedLessons.first?.overview == attributedOverview)
    }

    @Test
    func testAnalysisAcceptsAValidLessonWithNoSummaryItemsOrPractice() async {
        let minimal = TranscriptLessonAnalysis(
            overview: MeaningOverview(
                summary: [],
                mainPoint: "No high-value lesson content was identified.",
                supportingIdeas: [],
                toneAndRegister: "Neutral",
                contextNotes: []
            ),
            items: [],
            exercises: []
        )
        let store = StoreFake()
        let workflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(analysis: minimal),
            store: store
        )
        workflow.updateTranscript(LessonFixtures.transcript)

        await workflow.analyze()

        #expect(workflow.snapshot.phase == .ready)
        #expect(store.savedLessons.first?.items.isEmpty == true)
        #expect(store.savedLessons.first?.exercises.isEmpty == true)
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
        var saved = store.makeSavedLesson(sourceURL: "https://www.youtube.com/watch?v=example")
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
        #expect(workflow.snapshot.lesson?.sourceURL == "https://www.youtube.com/watch?v=example")
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

    @Test
    func supportedURLsAreCanonicalizedBeforeAcquisition() async {
        let source = VideoSource(
            canonicalURL: "https://www.youtube.com/watch?v=abc123",
            platform: .youtube,
            title: "A short lesson",
            durationSeconds: 120,
            primaryLanguage: "en"
        )
        let acquirer = AcquirerFake(
            result: TranscriptAcquisition(
                transcript: "English with một chút code-switching preserved.",
                source: source,
                method: .captions,
                detectedLanguage: "en",
                durationSeconds: 120
            )
        )
        let workflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(analysis: LessonFixtures.analysis()),
            store: StoreFake(),
            acquirer: acquirer,
            ankiWriter: AnkiWriterFake()
        )
        workflow.updateSourceURL("https://youtu.be/abc123?t=10")

        await workflow.acquireFromSourceURL()

        #expect(acquirer.sources.first?.platform == .youtube)
        #expect(acquirer.sources.first?.canonicalURL == "https://www.youtube.com/watch?v=abc123")
        #expect(workflow.snapshot.phase == .reviewing)
        #expect(workflow.snapshot.acquisitionMethod == .captions)
        #expect(workflow.snapshot.transcript.contains("một chút"))
    }

    @Test
    func durationAndEnglishRulesAreEnforcedBeforeAnalysis() async {
        let longSource = VideoSource(
            canonicalURL: "https://www.tiktok.com/@speaker/video/123",
            platform: .tiktok,
            title: nil,
            durationSeconds: 301,
            primaryLanguage: "en"
        )
        let longWorkflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(analysis: LessonFixtures.analysis()),
            store: StoreFake(),
            acquirer: AcquirerFake(
                result: TranscriptAcquisition(
                    transcript: "A complete transcript.",
                    source: longSource,
                    method: .captions,
                    detectedLanguage: "en",
                    durationSeconds: 301
                )
            ),
            ankiWriter: AnkiWriterFake()
        )
        longWorkflow.updateSourceURL(longSource.canonicalURL)
        await longWorkflow.acquireFromSourceURL()
        #expect(longWorkflow.snapshot.phase == .failed)
        #expect(longWorkflow.snapshot.errorMessage?.contains("five minutes") == true)
        #expect(longWorkflow.snapshot.canUseManualFallback)

        let nonEnglishSource = VideoSource(
            canonicalURL: "https://www.youtube.com/watch?v=spanish",
            platform: .youtube,
            title: nil,
            durationSeconds: 90,
            primaryLanguage: "es"
        )
        let nonEnglishWorkflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(analysis: LessonFixtures.analysis()),
            store: StoreFake(),
            acquirer: AcquirerFake(
                result: TranscriptAcquisition(
                    transcript: "Una transcripción.",
                    source: nonEnglishSource,
                    method: .speechToText,
                    detectedLanguage: "es",
                    durationSeconds: 90
                )
            ),
            ankiWriter: AnkiWriterFake()
        )
        nonEnglishWorkflow.updateSourceURL(nonEnglishSource.canonicalURL)
        await nonEnglishWorkflow.acquireFromSourceURL()
        #expect(nonEnglishWorkflow.snapshot.errorMessage?.contains("primarily es") == true)
    }

    @Test
    func localFileTranscriptionReachesReviewAndAnalysisStillWaits() async {
        let analyzer = AnalyzerFake(analysis: LessonFixtures.analysis())
        let acquirer = AcquirerFake(
            result: TranscriptAcquisition(
                transcript: LessonFixtures.transcript,
                source: nil,
                method: .speechToText,
                detectedLanguage: "english",
                durationSeconds: 181
            )
        )
        let workflow = TranscriptLessonWorkflow(
            analyzer: analyzer,
            store: StoreFake(),
            acquirer: acquirer,
            ankiWriter: AnkiWriterFake()
        )

        await workflow.transcribeLocalFile(URL(fileURLWithPath: "/tmp/authorized.mov"))

        #expect(acquirer.localFiles.map(\.path) == ["/tmp/authorized.mov"])
        #expect(workflow.snapshot.phase == .reviewing)
        #expect(workflow.snapshot.durationWarning != nil)
        #expect(analyzer.analyzeCalls.isEmpty)
    }

    @Test
    func manuallyEnteredTranscriptKeepsItsReviewedLineStructure() async {
        let manualTranscript = "\n" + LessonFixtures.transcript.replacingOccurrences(
            of: ", ",
            with: ",\n"
        ) + "\n"
        let analyzer = AnalyzerFake(analysis: LessonFixtures.analysis(transcript: manualTranscript))
        let store = StoreFake()
        let workflow = TranscriptLessonWorkflow(
            analyzer: analyzer,
            store: store,
            acquirer: AcquirerFake(),
            ankiWriter: AnkiWriterFake()
        )

        workflow.updateTranscript(manualTranscript)
        await workflow.analyze()

        #expect(workflow.snapshot.transcript == manualTranscript)
        #expect(analyzer.analyzeCalls == [manualTranscript])
        #expect(store.savedLessons.first?.approvedTranscript == manualTranscript)
    }

    @Test
    func missingCaptionsTransitionThroughUrlTranscriptionFallback() async {
        let source = VideoSource(
            canonicalURL: "https://www.youtube.com/watch?v=fallback",
            platform: .youtube,
            title: nil,
            durationSeconds: 90,
            primaryLanguage: "en"
        )
        let acquirer = AcquirerFake(
            result: TranscriptAcquisition(
                transcript: "A speech-to-text fallback transcript.",
                source: source,
                method: .speechToText,
                detectedLanguage: "en",
                durationSeconds: 90
            ),
            captionsAvailable: false
        )
        let workflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(analysis: LessonFixtures.analysis()),
            store: StoreFake(),
            acquirer: acquirer,
            ankiWriter: AnkiWriterFake()
        )
        workflow.updateSourceURL(source.canonicalURL)

        await workflow.acquireFromSourceURL()

        #expect(acquirer.transcribedSources.map(\.canonicalURL) == [source.canonicalURL])
        #expect(acquirer.transcribedSources.map(\.platform) == [source.platform])
        #expect(workflow.snapshot.acquisitionMethod == .speechToText)
        #expect(workflow.snapshot.phase == .reviewing)
    }

    @Test
    func terminalAndRetryableAcquisitionFailuresAreDistinguished() async {
        let terminal = TranscriptAcquisitionFailure(
            stage: .configuration,
            message: "Install ffmpeg.",
            retryable: false
        )
        let terminalWorkflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(analysis: LessonFixtures.analysis()),
            store: StoreFake(),
            acquirer: AcquirerFake(error: terminal),
            ankiWriter: AnkiWriterFake()
        )
        terminalWorkflow.updateSourceURL("https://youtu.be/terminal")
        await terminalWorkflow.acquireFromSourceURL()
        #expect(!terminalWorkflow.snapshot.canRetryAcquisition)
        #expect(terminalWorkflow.snapshot.canUseManualFallback)

        let retryable = TranscriptAcquisitionFailure(
            stage: .transcription,
            message: "Timed out.",
            retryable: true
        )
        let retryWorkflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(analysis: LessonFixtures.analysis()),
            store: StoreFake(),
            acquirer: AcquirerFake(error: retryable),
            ankiWriter: AnkiWriterFake()
        )
        retryWorkflow.updateSourceURL("https://youtu.be/retryable")
        await retryWorkflow.acquireFromSourceURL()
        #expect(retryWorkflow.snapshot.canRetryAcquisition)
        #expect(retryWorkflow.snapshot.failureStage == .transcription)
    }

    @Test
    func resetInvalidatesAnInFlightAcquisition() async {
        let acquirer = SuspendedAcquirerFake()
        let workflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(analysis: LessonFixtures.analysis()),
            store: StoreFake(),
            acquirer: acquirer,
            ankiWriter: AnkiWriterFake()
        )
        workflow.updateSourceURL("https://youtu.be/cancelled")
        let task = Task { await workflow.acquireFromSourceURL() }
        await Task.yield()

        workflow.reset()
        task.cancel()
        await task.value

        #expect(workflow.snapshot.phase == .sourceEntry)
        #expect(workflow.snapshot.transcript.isEmpty)
        #expect(acquirer.wasCancelled)
    }

    @Test
    func naturalEnglishExportPersistsIdentifierAndPreventsDuplicates() async {
        let store = StoreFake()
        let saved = store.makeSavedLesson(sourceURL: "https://www.youtube.com/watch?v=example")
        store.lessonsByID[42] = saved
        let writer = AnkiWriterFake(noteID: 987654321)
        let workflow = TranscriptLessonWorkflow(
            analyzer: AnalyzerFake(analysis: LessonFixtures.analysis()),
            store: store,
            acquirer: AcquirerFake(),
            ankiWriter: writer
        )
        await workflow.openLesson(id: 42)

        await workflow.exportToAnki(itemID: "item-1")
        await workflow.exportToAnki(itemID: "item-1")

        #expect(writer.notes.count == 1)
        #expect(writer.notes.first?.modelName == "Natural English")
        #expect(writer.notes.first?.fields["Expression or pattern"] == saved.items[0].expression)
        #expect(writer.notes.first?.fields["Original transcript example"] == saved.items[0].sourceExcerpt)
        #expect(writer.notes.first?.fields["Source URL"] == saved.sourceURL)
        #expect(store.savedExports.count == 1)
        #expect(workflow.snapshot.lesson?.items[0].ankiNoteID == 987654321)
        #expect(workflow.snapshot.errorMessage?.contains("already been exported") == true)
    }

    @Test
    func packagedWeeklyWorkflowPersistsPracticeExportAndSourceAcrossReopen() async throws {
        let source = VideoSource(
            canonicalURL: "https://www.youtube.com/watch?v=weekly",
            platform: .youtube,
            title: "Weekly English lesson",
            durationSeconds: 150,
            primaryLanguage: "en"
        )
        let reviewedTranscript = LessonFixtures.transcript.replacingOccurrences(
            of: ", ",
            with: ",\n"
        )
        let analyzer = AnalyzerFake(analysis: LessonFixtures.analysis(transcript: reviewedTranscript))
        let store = StoreFake()
        let writer = AnkiWriterFake(noteID: 808)
        let workflow = TranscriptLessonWorkflow(
            analyzer: analyzer,
            store: store,
            acquirer: AcquirerFake(
                result: TranscriptAcquisition(
                    transcript: LessonFixtures.transcript,
                    source: source,
                    method: .captions,
                    detectedLanguage: "en",
                    durationSeconds: 150
                )
            ),
            ankiWriter: writer
        )
        workflow.updateSourceURL("https://youtu.be/weekly")

        await workflow.acquireFromSourceURL()
        #expect(workflow.snapshot.phase == .reviewing)
        workflow.updateTranscript(reviewedTranscript)
        await workflow.analyze()
        #expect(workflow.snapshot.lesson?.overview.summary.count == 3)
        #expect(workflow.snapshot.lesson?.items.count == 6)

        await workflow.submitAnswer(
            exerciseID: "item-1-recognition",
            answer: "It introduces a contrast despite limited evidence."
        )
        await workflow.submitAnswer(
            exerciseID: "item-1-production",
            answer: "I took the broader context into account."
        )
        await workflow.exportToAnki(itemID: "item-1")
        await workflow.exportToAnki(itemID: "item-1")

        workflow.reset()
        await workflow.loadHistory()
        await workflow.openLesson(id: 42)

        let reopened = try #require(workflow.snapshot.lesson)
        #expect(reopened.approvedTranscript == reviewedTranscript)
        #expect(reopened.sourceURL == source.canonicalURL)
        #expect(reopened.source == source)
        #expect(reopened.attempts.count == 2)
        #expect(reopened.items[0].ankiNoteID == 808)
        #expect(writer.notes.count == 1)
        #expect(store.savedExports.count == 1)
    }

    @Test
    func retriesAnalysisAndLessonPersistenceAtTheirOwnStages() async {
        let analysisAnalyzer = AnalyzerFake(analysis: LessonFixtures.analysis(), analyzeFailuresRemaining: 1)
        let analysisWorkflow = TranscriptLessonWorkflow(analyzer: analysisAnalyzer, store: StoreFake())
        analysisWorkflow.updateTranscript(LessonFixtures.transcript)

        await analysisWorkflow.analyze()
        #expect(analysisWorkflow.snapshot.failureStage == .analysis)
        await analysisWorkflow.analyze()
        #expect(analysisAnalyzer.analyzeCalls.count == 2)
        #expect(analysisWorkflow.snapshot.phase == .ready)

        let persistenceAnalyzer = AnalyzerFake(analysis: LessonFixtures.analysis())
        let persistenceStore = StoreFake(saveLessonFailuresRemaining: 1)
        let persistenceWorkflow = TranscriptLessonWorkflow(
            analyzer: persistenceAnalyzer,
            store: persistenceStore
        )
        persistenceWorkflow.updateTranscript(LessonFixtures.transcript)

        await persistenceWorkflow.analyze()
        #expect(persistenceWorkflow.snapshot.failureStage == .persistence)
        await persistenceWorkflow.analyze()
        #expect(persistenceAnalyzer.analyzeCalls.count == 1)
        #expect(persistenceWorkflow.snapshot.phase == .ready)
    }

    @Test
    func retriesPracticePersistenceAndAnkiExportWithoutRepeatingExternalWork() async {
        let analyzer = AnalyzerFake(analysis: LessonFixtures.analysis())
        let store = StoreFake(saveAttemptFailuresRemaining: 1, saveExportFailuresRemaining: 1)
        store.lessonsByID[42] = store.makeSavedLesson()
        let writer = AnkiWriterFake(noteID: 909)
        let workflow = TranscriptLessonWorkflow(
            analyzer: analyzer,
            store: store,
            acquirer: AcquirerFake(),
            ankiWriter: writer
        )
        await workflow.openLesson(id: 42)

        let answer = "I took the broader context into account."
        await workflow.submitAnswer(exerciseID: "item-1-production", answer: answer)
        #expect(workflow.snapshot.failureStage == .persistence)
        await workflow.submitAnswer(exerciseID: "item-1-production", answer: answer)
        #expect(analyzer.evaluationRequests.count == 1)
        #expect(workflow.snapshot.lesson?.attempts.count == 1)

        await workflow.exportToAnki(itemID: "item-1")
        #expect(workflow.snapshot.failureStage == .persistence)
        await workflow.exportToAnki(itemID: "item-1")
        #expect(writer.notes.count == 1)
        #expect(store.savedExports.count == 1)
        #expect(workflow.snapshot.lesson?.items[0].ankiNoteID == 909)
    }

    @Test
    func noteMappingsPreserveSpecialCharactersAndMultilineText() {
        let boost = AnkiNoteMapping.boostVocab(
            deckName: "Vocab",
            modelName: "Basic",
            word: "rock & roll <3",
            meaning: "line one\nline two",
            wordType: "noun",
            example1: "‘Quoted’",
            example2: "emoji 🔬",
            tags: ["special"]
        )
        #expect(boost.fields["Word"] == "rock & roll <3")
        #expect(boost.fields["Meaning"] == "line one\nline two")
        #expect(Set(boost.fields.keys) == Set(["Word", "Meaning", "Word type", "Example 1", "Example 2"]))
    }
}

@Suite
struct TranscriptSourceURLTests {
    @Test
    func validatesYouTubeAndTikTokForms() throws {
        #expect(try TranscriptSourceURL.validate("https://youtube.com/shorts/abc").canonicalURL == "https://www.youtube.com/watch?v=abc")
        #expect(try TranscriptSourceURL.validate("https://m.youtube.com/watch?v=xyz&feature=share").platform == .youtube)
        #expect(try TranscriptSourceURL.validate("https://www.tiktok.com/@learner/video/123?lang=en").canonicalURL == "https://www.tiktok.com/@learner/video/123")
        #expect(try TranscriptSourceURL.validate("https://vm.tiktok.com/ZMabc123/").platform == .tiktok)
    }

    @Test
    func rejectsUnsupportedAndMalformedURLs() {
        #expect(throws: TranscriptSourceURLError.self) {
            try TranscriptSourceURL.validate("https://example.com/video/123")
        }
        #expect(throws: TranscriptSourceURLError.self) {
            try TranscriptSourceURL.validate("not a URL")
        }
    }

    @Test
    func acquisitionAdapterMapsStructuredAndMalformedFailures() throws {
        let structured = try JSONEncoder().encode(
            TranscriptAcquisitionFailure(
                stage: .transcription,
                message: "Speech service timed out.",
                retryable: true
            )
        )
        #expect(throws: TranscriptAcquisitionFailure.self) {
            try TranscriptAcquisitionAgentClient.decode(
                PythonProcessResult(output: Data(), errorOutput: structured, terminationStatus: 2)
            )
        }
        #expect(throws: TranscriptAcquisitionFailure.self) {
            try TranscriptAcquisitionAgentClient.decode(
                PythonProcessResult(output: Data("not-json".utf8), errorOutput: Data(), terminationStatus: 0)
            )
        }
        do {
            _ = try TranscriptAcquisitionAgentClient.decodeCaptionLookup(
                PythonProcessResult(output: Data("not-json".utf8), errorOutput: Data(), terminationStatus: 0)
            )
            Issue.record("Malformed caption output should fail")
        } catch let failure as TranscriptAcquisitionFailure {
            #expect(failure.stage == .acquisition)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
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
    var analyzeFailuresRemaining: Int

    init(analysis: TranscriptLessonAnalysis, analyzeFailuresRemaining: Int = 0) {
        self.analysis = analysis
        self.analyzeFailuresRemaining = analyzeFailuresRemaining
    }

    func analyze(transcript: String) async throws -> TranscriptLessonAnalysis {
        analyzeCalls.append(transcript)
        if analyzeFailuresRemaining > 0 {
            analyzeFailuresRemaining -= 1
            throw WorkflowFakeError.injected
        }
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
    var savedExports: [(noteID: Int64, itemID: String, lessonID: Int64)] = []
    var saveLessonFailuresRemaining: Int
    var saveAttemptFailuresRemaining: Int
    var saveExportFailuresRemaining: Int

    init(
        saveLessonFailuresRemaining: Int = 0,
        saveAttemptFailuresRemaining: Int = 0,
        saveExportFailuresRemaining: Int = 0
    ) {
        self.saveLessonFailuresRemaining = saveLessonFailuresRemaining
        self.saveAttemptFailuresRemaining = saveAttemptFailuresRemaining
        self.saveExportFailuresRemaining = saveExportFailuresRemaining
    }

    func saveLesson(_ lesson: TranscriptLesson) async throws -> TranscriptLesson {
        if saveLessonFailuresRemaining > 0 {
            saveLessonFailuresRemaining -= 1
            throw WorkflowFakeError.injected
        }
        savedLessons.append(lesson)
        var saved = lesson
        saved.id = 42
        saved.createdAt = "2026-08-27T00:00:00Z"
        lessonsByID[42] = saved
        summaries = [
            TranscriptLessonSummary(
                id: 42,
                createdAt: saved.createdAt!,
                sourceURL: saved.sourceURL,
                mainPoint: saved.overview.mainPoint,
                itemCount: saved.items.count
            )
        ]
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
        if saveAttemptFailuresRemaining > 0 {
            saveAttemptFailuresRemaining -= 1
            throw WorkflowFakeError.injected
        }
        var saved = attempt
        saved.id = Int64(savedAttempts.count + 1)
        saved.createdAt = "2026-08-27T00:00:00Z"
        savedAttempts.append(saved)
        lessonsByID[lessonID]?.attempts.append(saved)
        return saved
    }

    func saveAnkiExport(noteID: Int64, itemID: String, lessonID: Int64) async throws {
        if saveExportFailuresRemaining > 0 {
            saveExportFailuresRemaining -= 1
            throw WorkflowFakeError.injected
        }
        savedExports.append((noteID, itemID, lessonID))
        if let index = lessonsByID[lessonID]?.items.firstIndex(where: { $0.id == itemID }) {
            lessonsByID[lessonID]?.items[index].ankiNoteID = noteID
        }
    }

    func makeSavedLesson(sourceURL: String? = nil) -> TranscriptLesson {
        let analysis = LessonFixtures.analysis()
        return TranscriptLesson(
            id: 42,
            createdAt: "2026-08-27T00:00:00Z",
            sourceURL: sourceURL,
            approvedTranscript: LessonFixtures.transcript,
            overview: analysis.overview,
            items: analysis.items,
            exercises: analysis.exercises,
            attempts: []
        )
    }
}

@MainActor
private final class AcquirerFake: TranscriptAcquiring {
    var result: TranscriptAcquisition
    var error: Error?
    let captionsAvailable: Bool
    var sources: [VideoSource] = []
    var transcribedSources: [VideoSource] = []
    var localFiles: [URL] = []

    init(
        result: TranscriptAcquisition = TranscriptAcquisition(
            transcript: LessonFixtures.transcript,
            source: nil,
            method: .speechToText,
            detectedLanguage: "en",
            durationSeconds: 60
        ),
        error: Error? = nil,
        captionsAvailable: Bool = true
    ) {
        self.result = result
        self.error = error
        self.captionsAvailable = captionsAvailable
    }

    func acquireCaptions(source: VideoSource) async throws -> TranscriptAcquisition? {
        sources.append(source)
        if let error { throw error }
        return captionsAvailable ? result : nil
    }

    func transcribe(source: VideoSource) async throws -> TranscriptAcquisition {
        transcribedSources.append(source)
        if let error { throw error }
        return result
    }

    func transcribe(localFile: URL, source: VideoSource?) async throws -> TranscriptAcquisition {
        localFiles.append(localFile)
        if let error { throw error }
        return result
    }
}

@MainActor
private final class AnkiWriterFake: AnkiNoteWriting {
    let noteID: Int64
    var notes: [AnkiNote] = []

    init(noteID: Int64 = 123) {
        self.noteID = noteID
    }

    func write(_ note: AnkiNote) async throws -> Int64 {
        notes.append(note)
        return noteID
    }
}

@MainActor
private final class SuspendedAcquirerFake: TranscriptAcquiring {
    var wasCancelled = false

    func acquireCaptions(source: VideoSource) async throws -> TranscriptAcquisition? {
        do {
            try await Task.sleep(for: .seconds(30))
            return nil
        } catch {
            wasCancelled = true
            throw error
        }
    }

    func transcribe(source: VideoSource) async throws -> TranscriptAcquisition {
        throw CancellationError()
    }

    func transcribe(localFile: URL, source: VideoSource?) async throws -> TranscriptAcquisition {
        throw CancellationError()
    }
}

private enum StoreFakeError: Error {
    case lessonNotFound
}

private enum WorkflowFakeError: Error {
    case injected
}

private enum LessonFixtures {
    static let transcript = "Although the evidence was limited, Maya took the broader context into account, ruled out a quick fix, followed through on the experiment, came across an unexpected pattern, and ended up changing course."

    static func analysis(transcript approvedTranscript: String = transcript) -> TranscriptLessonAnalysis {
        let expressions: [(String, LanguageCategory)] = [
            ("Although the evidence was limited", .grammarPattern),
            ("took the broader context into account", .collocation),
            ("ruled out", .phrasalVerb),
            ("followed through", .phrasalVerb),
            ("came across", .phrasalVerb),
            ("ended up", .phrasalVerb)
        ]
        let items = expressions.enumerated().map { index, entry in
            let range = approvedTranscript.range(of: entry.0)!
            let start = range.lowerBound.utf16Offset(in: approvedTranscript)
            let end = range.upperBound.utf16Offset(in: approvedTranscript)
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
