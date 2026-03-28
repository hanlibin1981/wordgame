import Foundation

/// Represents a game level/chapter in the learning journey
struct GameLevel: Identifiable, Equatable, Hashable {
    let id: Int
    let bookId: String
    let chapter: Int      // Chapter number (1, 2, 3...)
    let stage: Int       // Stage within chapter (1, 2, 3)
    let name: String
    let wordIds: [String]
    let passingScore: Int  // Minimum correct rate to pass (0-100)
    let isBossLevel: Bool  // Boss challenge after every 3 stages

    var levelNumber: Int {
        return (chapter - 1) * 3 + stage
    }

    var displayName: String {
        if isBossLevel {
            return "Boss 挑战 - 第\(chapter)章"
        }
        return "第\(chapter)章 - 第\(stage)关"
    }

    var totalWords: Int {
        return wordIds.count
    }
}

/// Game progress for a specific word book
struct GameProgress: Identifiable, Codable, Equatable {
    let id: String
    var bookId: String
    var currentChapter: Int
    var currentStage: Int
    var starsEarned: Int
    var totalCorrect: Int
    var totalAnswered: Int
    var isCompleted: Bool
    var updatedAt: Date
    /// Tracks the highest chapter whose boss has been passed.
    /// Used for unlocking regular levels (1-3) of each chapter.
    /// Default=0 means no boss passed yet.
    var lastPassedBossChapter: Int

    init(
        id: String = UUID().uuidString,
        bookId: String,
        currentChapter: Int = 1,
        currentStage: Int = 1,
        starsEarned: Int = 0,
        totalCorrect: Int = 0,
        totalAnswered: Int = 0,
        isCompleted: Bool = false,
        updatedAt: Date = Date(),
        lastPassedBossChapter: Int = 0
    ) {
        self.id = id
        self.bookId = bookId
        self.currentChapter = currentChapter
        self.currentStage = currentStage
        self.starsEarned = starsEarned
        self.totalCorrect = totalCorrect
        self.totalAnswered = totalAnswered
        self.isCompleted = isCompleted
        self.updatedAt = updatedAt
        self.lastPassedBossChapter = lastPassedBossChapter
    }

    var accuracy: Double {
        guard totalAnswered > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAnswered) * 100
    }
}
