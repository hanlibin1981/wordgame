import Foundation
import SwiftUI
import os

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
}
