import Foundation

enum LanguageCategory: String, Codable, CaseIterable, Sendable {
    case vocabulary = "Vocabulary"
    case idiom = "Idiom"
    case phrasalVerb = "Phrasal verb"
    case collocation = "Collocation"
    case slang = "Slang"
    case grammarPattern = "Grammar pattern"
}

enum ExerciseKind: String, Codable, Sendable {
    case recognition
    case production
}

struct MeaningOverview: Codable, Equatable, Sendable {
    let summary: [String]
    let mainPoint: String
    let supportingIdeas: [String]
    let toneAndRegister: String
    let contextNotes: [String]
}

struct TranscriptLanguageItem: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let expression: String
    /// Inclusive UTF-16 code-unit offset in the approved transcript.
    let spanStart: Int
    /// Exclusive UTF-16 code-unit offset in the approved transcript.
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
}

struct LessonExercise: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let itemID: String
    let kind: ExerciseKind
    let prompt: String
    let expectedAnswer: String?
    let explanation: String?
}

struct ExerciseFeedback: Codable, Equatable, Sendable {
    let isCorrect: Bool
    let meaningFeedback: String
    let correctnessFeedback: String
    let appropriatenessFeedback: String
    let naturalnessFeedback: String
    let explanation: String
    let naturalRevision: String
}

struct ExerciseAttempt: Identifiable, Codable, Equatable, Sendable {
    var id: Int64?
    let exerciseID: String
    let answer: String
    let feedback: ExerciseFeedback
    var createdAt: String?
}

struct TranscriptLessonAnalysis: Codable, Equatable, Sendable {
    let overview: MeaningOverview
    let items: [TranscriptLanguageItem]
    let exercises: [LessonExercise]
}

struct TranscriptLesson: Identifiable, Codable, Equatable, Sendable {
    var id: Int64?
    var createdAt: String?
    let sourceURL: String?
    let approvedTranscript: String
    let overview: MeaningOverview
    let items: [TranscriptLanguageItem]
    let exercises: [LessonExercise]
    var attempts: [ExerciseAttempt]
}

struct TranscriptLessonSummary: Identifiable, Codable, Equatable, Sendable {
    let id: Int64
    let createdAt: String
    let sourceURL: String?
    let mainPoint: String
    let itemCount: Int
}

struct ExerciseEvaluationRequest: Codable, Equatable, Sendable {
    let transcript: String
    let item: TranscriptLanguageItem
    let exercise: LessonExercise
    let answer: String
}
