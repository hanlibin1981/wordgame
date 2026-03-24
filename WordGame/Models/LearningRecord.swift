import Foundation

/// Type of question in the learning game
enum QuestionType: String, Codable, CaseIterable {
    case choice = "choice"      // Multiple choice
    case spelling = "spelling"   // Word spelling
    case listening = "listening" // Audio listening

    var displayName: String {
        switch self {
        case .choice:
            return "选择题"
        case .spelling:
            return "拼写题"
        case .listening:
            return "听力题"
        }
    }

    var icon: String {
        switch self {
        case .choice:
            return "list.bullet"
        case .spelling:
            return "keyboard"
        case .listening:
            return "speaker.wave.2"
        }
    }
}

/// Represents a learning/answer record for analytics
struct LearningRecord: Identifiable, Codable {
    let id: String
    var wordId: String
    var bookId: String
    var result: Bool         // true = correct, false = wrong
    var questionType: QuestionType
    var answerTimeMs: Int     // Time taken to answer in milliseconds
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        wordId: String,
        bookId: String,
        result: Bool,
        questionType: QuestionType,
        answerTimeMs: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.wordId = wordId
        self.bookId = bookId
        self.result = result
        self.questionType = questionType
        self.answerTimeMs = answerTimeMs
        self.createdAt = createdAt
    }
}

/// Represents a single question in the game
struct GameQuestion: Identifiable {
    let id: String
    let word: Word
    let questionType: QuestionType
    var options: [String]?      // For choice questions
    var correctAnswer: String
    var userAnswer: String?
    var isAnswered: Bool = false
    var isCorrect: Bool? = nil

    init(
        id: String = UUID().uuidString,
        word: Word,
        questionType: QuestionType,
        options: [String]? = nil,
        correctAnswer: String? = nil
    ) {
        self.id = id
        self.word = word
        self.questionType = questionType
        self.options = options
        self.correctAnswer = correctAnswer ?? word.meaning
    }
}
