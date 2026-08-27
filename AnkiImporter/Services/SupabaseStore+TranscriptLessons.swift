import Foundation

@MainActor
extension SupabaseStore: TranscriptLessonStoring {
    func saveLesson(_ lesson: TranscriptLesson) async throws -> TranscriptLesson {
        let lessonRow = LessonInsertRow(
            sourceURL: lesson.sourceURL,
            approvedTranscript: lesson.approvedTranscript,
            summary: lesson.overview.summary,
            mainPoint: lesson.overview.mainPoint,
            supportingIdeas: lesson.overview.supportingIdeas,
            toneAndRegister: lesson.overview.toneAndRegister,
            contextNotes: lesson.overview.contextNotes,
            itemCount: lesson.items.count
        )
        let insertedData = try await transcriptRequest(
            table: "transcript_lessons",
            method: "POST",
            body: try JSONEncoder().encode(lessonRow),
            prefer: "return=representation"
        )
        guard let inserted = try JSONDecoder().decode([LessonRow].self, from: insertedData).first else {
            throw BatchStoreError.supabaseError("Transcript lesson insert response was empty.")
        }

        do {
            if !lesson.items.isEmpty {
                let itemRows = lesson.items.map { ItemRow(lessonID: inserted.id, item: $0) }
                _ = try await transcriptRequest(
                    table: "transcript_language_items",
                    method: "POST",
                    body: try JSONEncoder().encode(itemRows)
                )
            }
            if !lesson.exercises.isEmpty {
                let exerciseRows = lesson.exercises.map { ExerciseRow(lessonID: inserted.id, exercise: $0) }
                _ = try await transcriptRequest(
                    table: "transcript_exercises",
                    method: "POST",
                    body: try JSONEncoder().encode(exerciseRows)
                )
            }
        } catch {
            try? await deleteTranscriptLesson(id: inserted.id)
            throw error
        }

        var saved = lesson
        saved.id = inserted.id
        saved.createdAt = inserted.createdAt
        return saved
    }

    func loadLessonSummaries() async throws -> [TranscriptLessonSummary] {
        let data = try await transcriptRequest(
            table: "transcript_lessons",
            queryItems: [
                URLQueryItem(name: "select", value: "id,created_at,source_url,main_point,item_count"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )
        return try JSONDecoder().decode([LessonSummaryRow].self, from: data).map {
            TranscriptLessonSummary(
                id: $0.id,
                createdAt: $0.createdAt,
                sourceURL: $0.sourceURL,
                mainPoint: $0.mainPoint,
                itemCount: $0.itemCount
            )
        }
    }

    func loadLesson(id: Int64) async throws -> TranscriptLesson {
        let lessonPayload = try await transcriptRequest(
            table: "transcript_lessons",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        let itemPayload = try await transcriptRequest(
            table: "transcript_language_items",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "lesson_id", value: "eq.\(id)"),
                URLQueryItem(name: "order", value: "span_start.asc")
            ]
        )
        let exercisePayload = try await transcriptRequest(
            table: "transcript_exercises",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "lesson_id", value: "eq.\(id)"),
                URLQueryItem(name: "order", value: "id.asc")
            ]
        )
        let attemptPayload = try await transcriptRequest(
            table: "transcript_exercise_attempts",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "lesson_id", value: "eq.\(id)"),
                URLQueryItem(name: "order", value: "created_at.asc")
            ]
        )

        guard let row = try JSONDecoder().decode([LessonRow].self, from: lessonPayload).first else {
            throw BatchStoreError.validation("Saved transcript lesson not found.")
        }
        let items = try JSONDecoder().decode([ItemRow].self, from: itemPayload).map(\.item)
        let exercises = try JSONDecoder().decode([ExerciseRow].self, from: exercisePayload).map(\.exercise)
        let attempts = try JSONDecoder().decode([AttemptRow].self, from: attemptPayload).map(\.attempt)

        return TranscriptLesson(
            id: row.id,
            createdAt: row.createdAt,
            sourceURL: row.sourceURL,
            approvedTranscript: row.approvedTranscript,
            overview: MeaningOverview(
                summary: row.summary,
                mainPoint: row.mainPoint,
                supportingIdeas: row.supportingIdeas,
                toneAndRegister: row.toneAndRegister,
                contextNotes: row.contextNotes
            ),
            items: items,
            exercises: exercises,
            attempts: attempts
        )
    }

    func saveAttempt(_ attempt: ExerciseAttempt, lessonID: Int64) async throws -> ExerciseAttempt {
        let row = AttemptInsertRow(lessonID: lessonID, attempt: attempt)
        let data = try await transcriptRequest(
            table: "transcript_exercise_attempts",
            method: "POST",
            body: try JSONEncoder().encode(row),
            prefer: "return=representation"
        )
        guard let inserted = try JSONDecoder().decode([AttemptRow].self, from: data).first else {
            throw BatchStoreError.supabaseError("Exercise attempt insert response was empty.")
        }
        return inserted.attempt
    }

    private func transcriptRequest(
        table: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        prefer: String? = nil
    ) async throws -> Data {
        var components = URLComponents(
            url: url.appendingPathComponent("rest/v1/\(table)"),
            resolvingAgainstBaseURL: true
        )
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let endpoint = components?.url else {
            throw BatchStoreError.supabaseError("Invalid transcript lesson database URL.")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.httpBody = body
        applySupabaseAuth(to: &request)
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw BatchStoreError.supabaseError(
                "Transcript lessons — \(Self.describeRestFailure(status: status, body: data))"
            )
        }
        return data
    }

    private func deleteTranscriptLesson(id: Int64) async throws {
        _ = try await transcriptRequest(
            table: "transcript_lessons",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id)")]
        )
    }
}

private struct LessonInsertRow: Encodable {
    let sourceURL: String?
    let approvedTranscript: String
    let summary: [String]
    let mainPoint: String
    let supportingIdeas: [String]
    let toneAndRegister: String
    let contextNotes: [String]
    let itemCount: Int

    enum CodingKeys: String, CodingKey {
        case summary
        case sourceURL = "source_url"
        case approvedTranscript = "approved_transcript"
        case mainPoint = "main_point"
        case supportingIdeas = "supporting_ideas"
        case toneAndRegister = "tone_and_register"
        case contextNotes = "context_notes"
        case itemCount = "item_count"
    }
}

private struct LessonRow: Decodable {
    let id: Int64
    let createdAt: String
    let sourceURL: String?
    let approvedTranscript: String
    let summary: [String]
    let mainPoint: String
    let supportingIdeas: [String]
    let toneAndRegister: String
    let contextNotes: [String]

    enum CodingKeys: String, CodingKey {
        case id, summary
        case createdAt = "created_at"
        case sourceURL = "source_url"
        case approvedTranscript = "approved_transcript"
        case mainPoint = "main_point"
        case supportingIdeas = "supporting_ideas"
        case toneAndRegister = "tone_and_register"
        case contextNotes = "context_notes"
    }
}

private struct LessonSummaryRow: Decodable {
    let id: Int64
    let createdAt: String
    let sourceURL: String?
    let mainPoint: String
    let itemCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case sourceURL = "source_url"
        case mainPoint = "main_point"
        case itemCount = "item_count"
    }
}

private struct ItemRow: Codable {
    let lessonID: Int64
    let itemKey: String
    let expression: String
    let spanStart: Int
    let spanEnd: Int
    let sourceExcerpt: String
    let primaryCategory: LanguageCategory
    let secondaryCategories: [LanguageCategory]
    let meaningAndUsage: String
    let cefrEstimate: String
    let selectionRationale: String
    let naturalExample: String
    let vietnameseGloss: String?
    let practicePriority: Int?

    init(lessonID: Int64, item: TranscriptLanguageItem) {
        self.lessonID = lessonID
        itemKey = item.id
        expression = item.expression
        spanStart = item.spanStart
        spanEnd = item.spanEnd
        sourceExcerpt = item.sourceExcerpt
        primaryCategory = item.primaryCategory
        secondaryCategories = item.secondaryCategories
        meaningAndUsage = item.meaningAndUsage
        cefrEstimate = item.cefrEstimate
        selectionRationale = item.selectionRationale
        naturalExample = item.naturalExample
        vietnameseGloss = item.vietnameseGloss
        practicePriority = item.practicePriority
    }

    var item: TranscriptLanguageItem {
        TranscriptLanguageItem(
            id: itemKey,
            expression: expression,
            spanStart: spanStart,
            spanEnd: spanEnd,
            sourceExcerpt: sourceExcerpt,
            primaryCategory: primaryCategory,
            secondaryCategories: secondaryCategories,
            meaningAndUsage: meaningAndUsage,
            cefrEstimate: cefrEstimate,
            selectionRationale: selectionRationale,
            naturalExample: naturalExample,
            vietnameseGloss: vietnameseGloss,
            practicePriority: practicePriority
        )
    }

    enum CodingKeys: String, CodingKey {
        case expression
        case lessonID = "lesson_id"
        case itemKey = "item_key"
        case spanStart = "span_start"
        case spanEnd = "span_end"
        case sourceExcerpt = "source_excerpt"
        case primaryCategory = "primary_category"
        case secondaryCategories = "secondary_categories"
        case meaningAndUsage = "meaning_and_usage"
        case cefrEstimate = "cefr_estimate"
        case selectionRationale = "selection_rationale"
        case naturalExample = "natural_example"
        case vietnameseGloss = "vietnamese_gloss"
        case practicePriority = "practice_priority"
    }
}

private struct ExerciseRow: Codable {
    let lessonID: Int64
    let exerciseKey: String
    let itemKey: String
    let kind: ExerciseKind
    let prompt: String
    let expectedAnswer: String?
    let explanation: String?

    init(lessonID: Int64, exercise: LessonExercise) {
        self.lessonID = lessonID
        exerciseKey = exercise.id
        itemKey = exercise.itemID
        kind = exercise.kind
        prompt = exercise.prompt
        expectedAnswer = exercise.expectedAnswer
        explanation = exercise.explanation
    }

    var exercise: LessonExercise {
        LessonExercise(
            id: exerciseKey,
            itemID: itemKey,
            kind: kind,
            prompt: prompt,
            expectedAnswer: expectedAnswer,
            explanation: explanation
        )
    }

    enum CodingKeys: String, CodingKey {
        case kind, prompt, explanation
        case lessonID = "lesson_id"
        case exerciseKey = "exercise_key"
        case itemKey = "item_key"
        case expectedAnswer = "expected_answer"
    }
}

private struct AttemptInsertRow: Encodable {
    let lessonID: Int64
    let exerciseKey: String
    let answer: String
    let isCorrect: Bool
    let meaningFeedback: String
    let correctnessFeedback: String
    let appropriatenessFeedback: String
    let naturalnessFeedback: String
    let explanation: String
    let naturalRevision: String

    init(lessonID: Int64, attempt: ExerciseAttempt) {
        self.lessonID = lessonID
        exerciseKey = attempt.exerciseID
        answer = attempt.answer
        isCorrect = attempt.feedback.isCorrect
        meaningFeedback = attempt.feedback.meaningFeedback
        correctnessFeedback = attempt.feedback.correctnessFeedback
        appropriatenessFeedback = attempt.feedback.appropriatenessFeedback
        naturalnessFeedback = attempt.feedback.naturalnessFeedback
        explanation = attempt.feedback.explanation
        naturalRevision = attempt.feedback.naturalRevision
    }

    enum CodingKeys: String, CodingKey {
        case answer, explanation
        case lessonID = "lesson_id"
        case exerciseKey = "exercise_key"
        case isCorrect = "is_correct"
        case meaningFeedback = "meaning_feedback"
        case correctnessFeedback = "correctness_feedback"
        case appropriatenessFeedback = "appropriateness_feedback"
        case naturalnessFeedback = "naturalness_feedback"
        case naturalRevision = "natural_revision"
    }
}

private struct AttemptRow: Decodable {
    let id: Int64
    let exerciseKey: String
    let answer: String
    let isCorrect: Bool
    let meaningFeedback: String
    let correctnessFeedback: String
    let appropriatenessFeedback: String
    let naturalnessFeedback: String
    let explanation: String
    let naturalRevision: String
    let createdAt: String

    var attempt: ExerciseAttempt {
        ExerciseAttempt(
            id: id,
            exerciseID: exerciseKey,
            answer: answer,
            feedback: ExerciseFeedback(
                isCorrect: isCorrect,
                meaningFeedback: meaningFeedback,
                correctnessFeedback: correctnessFeedback,
                appropriatenessFeedback: appropriatenessFeedback,
                naturalnessFeedback: naturalnessFeedback,
                explanation: explanation,
                naturalRevision: naturalRevision
            ),
            createdAt: createdAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, answer, explanation
        case exerciseKey = "exercise_key"
        case isCorrect = "is_correct"
        case meaningFeedback = "meaning_feedback"
        case correctnessFeedback = "correctness_feedback"
        case appropriatenessFeedback = "appropriateness_feedback"
        case naturalnessFeedback = "naturalness_feedback"
        case naturalRevision = "natural_revision"
        case createdAt = "created_at"
    }
}
