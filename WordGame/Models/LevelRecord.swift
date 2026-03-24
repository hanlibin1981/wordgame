import Foundation

/// Records a single level's completion status for a word book.
struct LevelRecord: Identifiable, Codable, Equatable {
    let id: String
    let bookId: String
    let chapter: Int
    let stage: Int  // 1-3 for regular, 4 for boss
    var isPassed: Bool
    var starsEarned: Int
    let completedAt: Date

    init(
        id: String = UUID().uuidString,
        bookId: String,
        chapter: Int,
        stage: Int,
        isPassed: Bool,
        starsEarned: Int,
        completedAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.chapter = chapter
        self.stage = stage
        self.isPassed = isPassed
        self.starsEarned = starsEarned
        self.completedAt = completedAt
    }

    /// Returns true if this record represents a boss level.
    var isBossLevel: Bool {
        stage == 4
    }
}
