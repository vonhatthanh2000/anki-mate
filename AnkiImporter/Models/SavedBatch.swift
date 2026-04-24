import Foundation

struct SavedBatchWord: Identifiable, Hashable {
    let id: Int64
    var word: String
    var meaning: String
    var wordType: String
    var example1: String
    var example2: String
    let topicId: Int64
    let topicName: String?
}

struct SavedBatch: Identifiable, Hashable {
    let id: Int64
    let createdAt: String
    let words: [SavedBatchWord]
    let paragraph: String
}
