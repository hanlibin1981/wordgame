import Foundation
import SwiftUI
import os

enum ReviewContentState: Equatable {
    case noPassedLevels
    case dueWords
    case fallbackWords
}

/// ViewModel for learning/review mode
@MainActor
final class LearningViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.wordgame.learning", category: "LearningViewModel")
    @Published var currentWord: Word?
    @Published var showAnswer = false
    @Published var isCorrect: Bool?
    @Published var reviewWords: [Word] = []
    @Published var currentIndex = 0
    @Published var masteryFilter: Int? = nil
    @Published var reviewContentState: ReviewContentState = .noPassedLevels

    private let database = DatabaseService.shared

    /// Load words for review based on mastery filter
    func loadReviewWords(for bookId: String, masteryLevel: Int? = nil) async {
        masteryFilter = masteryLevel

        do {
            var words = try database.fetchWords(forBookId: bookId)

            // Filter by mastery level if specified
            if let level = masteryLevel {
                words = words.filter { $0.masteryLevel <= level }
            }

            // Sort by: words never reviewed first, then by mastery level (lowest first)
            words.sort { word1, word2 in
                if word1.lastReviewedAt == nil && word2.lastReviewedAt != nil {
                    return true
                }
                if word1.lastReviewedAt != nil && word2.lastReviewedAt == nil {
                    return false
                }
                return word1.masteryLevel < word2.masteryLevel
            }

            reviewWords = words
            currentIndex = 0
            currentWord = words.first
            showAnswer = false
            isCorrect = nil
        } catch {
            logger.error("Failed to load review words: \(error.localizedDescription)")
        }
    }

    /// Reveal the answer
    func revealAnswer() {
        showAnswer = true
    }

    /// Mark current word as known (correct)
    func markAsKnown() async {
        guard let word = currentWord else { return }

        isCorrect = true
        var updatedWord = word
        updatedWord.masteryLevel = min(5, word.masteryLevel + 1)
        updatedWord.lastReviewedAt = Date()

        try? database.updateWord(updatedWord)

        await recordAnswer(for: updatedWord, correct: true)

        await moveToNext()
    }

    /// Mark current word as unknown (wrong)
    func markAsUnknown() async {
        guard let word = currentWord else { return }

        isCorrect = false
        var updatedWord = word
        updatedWord.masteryLevel = max(0, word.masteryLevel - 1)
        updatedWord.wrongCount = word.wrongCount + 1
        updatedWord.lastReviewedAt = Date()

        try? database.updateWord(updatedWord)

        await recordAnswer(for: updatedWord, correct: false)

        await moveToNext()
    }

    /// Move to the next word
    func moveToNext() async {
        if currentIndex + 1 < reviewWords.count {
            currentIndex += 1
            currentWord = reviewWords[currentIndex]
            showAnswer = false
            isCorrect = nil
        }
    }

    /// Skip current word
    func skipWord() async {
        await moveToNext()
    }

    /// Record learning for analytics
    private func recordAnswer(for word: Word, correct: Bool) async {
        let record = LearningRecord(
            wordId: word.id,
            bookId: word.bookId,
            result: correct,
            questionType: .choice,  // Review mode is treated as choice
            answerTimeMs: 0
        )

        try? database.createLearningRecord(record)
    }

    /// Get progress text
    var progressText: String {
        "\(currentIndex + 1) / \(reviewWords.count)"
    }

    /// Get mastery distribution for a book
    func getMasteryDistribution(for bookId: String) async -> [Int: Int] {
        do {
            let words = try database.fetchWords(forBookId: bookId)
            var distribution: [Int: Int] = [:]

            for level in 0...5 {
                distribution[level] = words.filter { $0.masteryLevel == level }.count
            }

            return distribution
        } catch {
            return [:]
        }
    }

    // MARK: - Ebbinghaus Review Method

    /// Maximum number of words per review session
    private let maxReviewWords = 30

    /// Review intervals in days for each mastery level (Ebbinghaus forgetting curve)
    /// Level 0: review immediately, Level 1: 1 day, Level 2: 3 days, Level 3: 7 days, Level 4: 14 days, Level 5: 30 days
    private let reviewIntervalDays: [Int: Int] = [
        0: 0,   // Immediate review
        1: 1,   // 1 day
        2: 3,   // 3 days
        3: 7,   // 7 days
        4: 14,  // 14 days
        5: 30   // 30 days
    ]

    /// Calculate the next review date for a word based on its mastery level and last review date.
    private func nextReviewDate(for word: Word) -> Date? {
        guard let lastReviewed = word.lastReviewedAt else {
            // Never reviewed, needs review now
            return Date()
        }
        let intervalDays = reviewIntervalDays[word.masteryLevel] ?? 1
        return Calendar.current.date(byAdding: .day, value: intervalDays, to: lastReviewed)
    }

    /// Check if a word is due for review based on Ebbinghaus method.
    private func isDueForReview(_ word: Word) -> Bool {
        guard let nextDate = nextReviewDate(for: word) else { return true }
        return Date() >= nextDate
    }

    /// Load words for Ebbinghaus review - only passed level words, due for review, max 30.
    func loadEbbinghausReviewWords(for book: WordBook, levels: [GameLevel]) async {
        do {
            // Get all passed level records
            let levelRecords = try database.fetchAllLevelRecords(forBookId: book.id)
            let passedLevels = Set(levelRecords.filter { $0.isPassed }.map { "\($0.chapter)-\($0.stage)" })

            // Collect words from passed levels
            var passedWords: [Word] = []
            for level in levels {
                let levelKey = "\(level.chapter)-\(level.stage)"
                if passedLevels.contains(levelKey) {
                    let levelWordIds = Set(level.wordIds)
                    let words = try database.fetchWords(forBookId: book.id)
                    passedWords.append(contentsOf: words.filter { levelWordIds.contains($0.id) })
                }
            }

            // Filter words due for review using Ebbinghaus method
            let dueWords = passedWords.filter { isDueForReview($0) }

            // Sort by urgency: overdue longest first, then by mastery level (lowest first)
            let sortedDueWords = dueWords.sorted { word1, word2 in
                let next1 = nextReviewDate(for: word1) ?? Date.distantPast
                let next2 = nextReviewDate(for: word2) ?? Date.distantPast
                if next1 != next2 {
                    return next1 < next2  // More overdue first
                }
                return word1.masteryLevel < word2.masteryLevel
            }

            let fallbackWords = passedWords.sorted { word1, word2 in
                if word1.masteryLevel != word2.masteryLevel {
                    return word1.masteryLevel < word2.masteryLevel
                }

                switch (word1.lastReviewedAt, word2.lastReviewedAt) {
                case (nil, nil):
                    return word1.createdAt < word2.createdAt
                case (nil, _?):
                    return true
                case (_?, nil):
                    return false
                case let (date1?, date2?):
                    if date1 != date2 {
                        return date1 < date2
                    }
                    return word1.createdAt < word2.createdAt
                }
            }

            if !sortedDueWords.isEmpty {
                reviewWords = Array(sortedDueWords.prefix(maxReviewWords))
                reviewContentState = .dueWords
            } else if !fallbackWords.isEmpty {
                // Keep the review entry useful even when nothing is strictly due yet.
                reviewWords = Array(fallbackWords.prefix(maxReviewWords))
                reviewContentState = .fallbackWords
            } else {
                reviewWords = []
                reviewContentState = .noPassedLevels
            }

            currentIndex = 0
            currentWord = reviewWords.first
            showAnswer = false
            isCorrect = nil
        } catch {
            logger.error("Failed to load Ebbinghaus review words: \(error.localizedDescription)")
            reviewWords = []
            reviewContentState = .noPassedLevels
        }
    }
}
