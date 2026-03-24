import Foundation

/// Represents a single vocabulary word with its metadata
struct Word: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var bookId: String
    var word: String
    var phonetic: String?
    var meaning: String
    var sentence: String?
    var audioUrl: String?
    var masteryLevel: Int  // 0-5 scale
    var wrongCount: Int
    var lastReviewedAt: Date?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        bookId: String,
        word: String,
        phonetic: String? = nil,
        meaning: String,
        sentence: String? = nil,
        audioUrl: String? = nil,
        masteryLevel: Int = 0,
        wrongCount: Int = 0,
        lastReviewedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.word = word
        self.phonetic = phonetic
        self.meaning = meaning
        self.sentence = sentence
        self.audioUrl = audioUrl
        self.masteryLevel = masteryLevel
        self.wrongCount = wrongCount
        self.lastReviewedAt = lastReviewedAt
        self.createdAt = createdAt
    }

    /// Returns a formatted phonetic string with pronunciation marks
    var formattedPhonetic: String {
        guard let phonetic = phonetic, !phonetic.isEmpty else {
            return ""
        }
        return "/\(phonetic)/"
    }
}
