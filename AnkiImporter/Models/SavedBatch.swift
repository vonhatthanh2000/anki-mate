import Foundation

struct SavedBatchWord: Identifiable, Hashable {
    let id: Int64
    let word: String
    let meaning: String
    let wordType: String
    let example1: String
    let example2: String
    let topicId: Int64
    let topicName: String?
}

struct SavedBatch: Identifiable, Hashable {
    let id: Int64
    let createdAt: String
    let words: [SavedBatchWord]
    let paragraph: String
}
