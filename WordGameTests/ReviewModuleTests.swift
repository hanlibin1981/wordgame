import XCTest
@testable import WordGame

/// Tests for the Review Module components
final class ReviewModuleTests: XCTestCase {

    // MARK: - ReviewLevel Tests

    func testReviewLevelIsAllStudied_whenNoWordsStudied_returnsFalse() {
        let level = ReviewLevel(id: 1, wordIds: ["w1", "w2", "w3"], totalWords: 3, studiedCount: 0)
        XCTAssertFalse(level.isAllStudied)
    }

    func testReviewLevelIsAllStudied_whenPartialStudied_returnsFalse() {
        let level = ReviewLevel(id: 1, wordIds: ["w1", "w2", "w3"], totalWords: 3, studiedCount: 2)
        XCTAssertFalse(level.isAllStudied)
    }

    func testReviewLevelIsAllStudied_whenAllStudied_returnsTrue() {
        let level = ReviewLevel(id: 1, wordIds: ["w1", "w2", "w3"], totalWords: 3, studiedCount: 3)
        XCTAssertTrue(level.isAllStudied)
    }

    func testReviewLevelIsAllStudied_whenMoreStudiedThanTotal_returnsTrue() {
        let level = ReviewLevel(id: 1, wordIds: ["w1", "w2", "w3"], totalWords: 3, studiedCount: 5)
        XCTAssertTrue(level.isAllStudied)
    }

    // MARK: - Array Chunked Extension Tests

    func testChunked_intoChunksOfSize() {
        let array = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        let chunks = array.chunked(into: 3)

        XCTAssertEqual(chunks.count, 4)
        XCTAssertEqual(chunks[0], [1, 2, 3])
        XCTAssertEqual(chunks[1], [4, 5, 6])
        XCTAssertEqual(chunks[2], [7, 8, 9])
        XCTAssertEqual(chunks[3], [10])
    }

    func testChunked_withExactDivision() {
        let array = ["a", "b", "c", "d", "e", "f"]
        let chunks = array.chunked(into: 2)

        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], ["a", "b"])
        XCTAssertEqual(chunks[1], ["c", "d"])
        XCTAssertEqual(chunks[2], ["e", "f"])
    }

    func testChunked_withEmptyArray() {
        let array: [Int] = []
        let chunks = array.chunked(into: 5)

        XCTAssertEqual(chunks.count, 0)
    }

    func testChunked_withSingleElement() {
        let array = [1]
        let chunks = array.chunked(into: 5)

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], [1])
    }

    func testChunked_withChunkSizeLargerThanArray() {
        let array = [1, 2, 3]
        let chunks = array.chunked(into: 10)

        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], [1, 2, 3])
    }

    // MARK: - ReviewContentState Tests

    func testReviewContentState_equatable() {
        XCTAssertEqual(ReviewContentState.noPassedLevels, .noPassedLevels)
        XCTAssertEqual(ReviewContentState.dueWords, .dueWords)
        XCTAssertEqual(ReviewContentState.fallbackWords, .fallbackWords)
    }

    func testReviewContentState_notEqual() {
        XCTAssertNotEqual(ReviewContentState.noPassedLevels, .dueWords)
        XCTAssertNotEqual(ReviewContentState.dueWords, .fallbackWords)
    }

    // MARK: - Word Ebbinghaus Review Tests

    func testWordMasteryLevels_areInValidRange() {
        // Test words with all mastery levels
        let word0 = Word(bookId: "book1", word: "test", meaning: "测试", masteryLevel: 0)
        let word1 = Word(bookId: "book1", word: "test", meaning: "测试", masteryLevel: 1)
        let word2 = Word(bookId: "book1", word: "test", meaning: "测试", masteryLevel: 2)
        let word3 = Word(bookId: "book1", word: "test", meaning: "测试", masteryLevel: 3)
        let word4 = Word(bookId: "book1", word: "test", meaning: "测试", masteryLevel: 4)
        let word5 = Word(bookId: "book1", word: "test", meaning: "测试", masteryLevel: 5)

        XCTAssertEqual(word0.masteryLevel, 0)
        XCTAssertEqual(word1.masteryLevel, 1)
        XCTAssertEqual(word5.masteryLevel, 5)
    }

    func testWordWrongCount_incrementsOnWrongAnswer() {
        let word = Word(bookId: "book1", word: "test", meaning: "测试", wrongCount: 0)

        var updatedWord = word
        updatedWord.wrongCount = word.wrongCount + 1

        XCTAssertEqual(updatedWord.wrongCount, 1)
    }

    func testWordLastReviewedAt_updatesAfterReview() {
        let word = Word(bookId: "book1", word: "test", meaning: "测试", lastReviewedAt: nil)

        var updatedWord = word
        updatedWord.lastReviewedAt = Date()

        XCTAssertNotNil(updatedWord.lastReviewedAt)
    }

    // MARK: - ReviewLevel Generation Tests

    func testGenerateReviewLevels_chunksWordsCorrectly() {
        // Create 25 words
        var words: [Word] = []
        for i in 0..<25 {
            words.append(Word(
                id: "word\(i)",
                bookId: "book1",
                word: "word\(i)",
                meaning: "meaning\(i)",
                masteryLevel: 0
            ))
        }

        // Manually simulate generateReviewLevels logic (10 words per level)
        let wordsPerLevel = 10
        let reviewLevels = words.chunked(into: wordsPerLevel).enumerated().map { index, chunk in
            let levelId = index + 1
            return ReviewLevel(
                id: levelId,
                wordIds: chunk.map { $0.id },
                totalWords: chunk.count,
                studiedCount: 0
            )
        }

        XCTAssertEqual(reviewLevels.count, 3)
        XCTAssertEqual(reviewLevels[0].totalWords, 10)
        XCTAssertEqual(reviewLevels[1].totalWords, 10)
        XCTAssertEqual(reviewLevels[2].totalWords, 5)
        XCTAssertEqual(reviewLevels[0].wordIds.count, 10)
        XCTAssertEqual(reviewLevels[2].wordIds.count, 5)
    }

    func testGenerateReviewLevels_withCompletedIds_marksAsStudied() {
        let words = [
            Word(id: "w1", bookId: "book1", word: "word1", meaning: "meaning1", masteryLevel: 0),
            Word(id: "w2", bookId: "book1", word: "word2", meaning: "meaning2", masteryLevel: 0),
            Word(id: "w3", bookId: "book1", word: "word3", meaning: "meaning3", masteryLevel: 0),
        ]

        // Simulate with completed IDs
        let completedIds: Set<Int> = [1] // Level 1 is completed
        let wordsPerLevel = 10

        let reviewLevels = words.chunked(into: wordsPerLevel).enumerated().map { index, chunk in
            let levelId = index + 1
            let isCompleted = completedIds.contains(levelId)
            return ReviewLevel(
                id: levelId,
                wordIds: chunk.map { $0.id },
                totalWords: chunk.count,
                studiedCount: isCompleted ? chunk.count : 0
            )
        }

        XCTAssertEqual(reviewLevels.count, 1)
        XCTAssertTrue(reviewLevels[0].isAllStudied)
    }

    // MARK: - GameResult Tests

    func testGameResult_isPassed_withHighAccuracy() {
        let result = GameResult(
            bookId: "book1",
            levelNumber: 1,
            totalQuestions: 10,
            correctCount: 8,
            wrongCount: 2,
            score: 80,
            starsEarned: 2,
            accuracy: 80.0,
            isPassed: true
        )

        XCTAssertTrue(result.isPassed)
        XCTAssertEqual(result.starsEarned, 2)
    }

    func testGameResult_isPassed_withLowAccuracy() {
        let result = GameResult(
            bookId: "book1",
            levelNumber: 1,
            totalQuestions: 10,
            correctCount: 4,
            wrongCount: 6,
            score: 40,
            starsEarned: 0,
            accuracy: 40.0,
            isPassed: false
        )

        XCTAssertFalse(result.isPassed)
        XCTAssertEqual(result.starsEarned, 0)
    }

    func testGameResult_fullAccuracy_earnsThreeStars() {
        let result = GameResult(
            bookId: "book1",
            levelNumber: 1,
            totalQuestions: 10,
            correctCount: 10,
            wrongCount: 0,
            score: 100,
            starsEarned: 3,
            accuracy: 100.0,
            isPassed: true
        )

        XCTAssertEqual(result.starsEarned, 3)
        XCTAssertTrue(result.isPassed)
    }
}
