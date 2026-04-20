import Foundation

struct WordPair: Identifiable, Codable {
    let id: UUID
    var word: String
    var meaning: String

    init(id: UUID = UUID(), word: String, meaning: String) {
        self.id = id
        self.word = word
        self.meaning = meaning
    }
}
