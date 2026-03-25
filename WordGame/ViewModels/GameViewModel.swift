import Foundation
import SwiftUI

/// ViewModel for game/learning session management
@MainActor
final class GameViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentBook: WordBook?
    @Published var currentLevel: GameLevel?
    @Published var questions: [GameQuestion] = []
    @Published var currentQuestionIndex = 0
    @Published var score = 0
    @Published var correctCount = 0
    @Published var wrongCount = 0
    @Published var isGameActive = false
    @Published var isGameCompleted = false
    /// True while progress is being saved to DB after game ends (blocks navigation)
    @Published var isSavingProgress = false
    @Published var gameResult: GameResult?
    @Published var starsEarned = 0

    // MARK: - Private Properties
    private var allWords: [Word] = []
    /// Time when the current question was shown to the user (for accurate answer time tracking)
    private var currentQuestionStartTime: Date?
    private let database = DatabaseService.shared

    // MARK: - Computed Properties
    var currentQuestion: GameQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentQuestionIndex) / Double(questions.count)
    }

    var totalQuestions: Int {
        questions.count
    }

    // MARK: - Game Lifecycle
    /// Start a new game for the given word book
    func startGame(for book: WordBook, level: GameLevel? = nil) async {
        currentBook = book
        currentLevel = level

        // Reset state first
        currentQuestionIndex = 0
        score = 0
        correctCount = 0
        wrongCount = 0
        isGameActive = false
        isGameCompleted = false
        gameResult = nil
        starsEarned = 0
        // Note: currentQuestionStartTime is set when the first question is actually shown

        // Load all words for the book
        do {
            allWords = try database.fetchWords(forBookId: book.id)
        } catch {
            print("Failed to load words: \(error)")
            return
        }

        // Check if we have words
        guard !allWords.isEmpty else {
            print("No words found in book: \(book.name)")
            return
        }

        // Generate questions for this level
        generateQuestions(for: level)

        // Only activate game if we have questions
        if !questions.isEmpty {
            isGameActive = true
            // Record when the first question is shown — this is the baseline for answer time
            currentQuestionStartTime = Date()
        }

        // Load or create progress
        _ = try? database.fetchOrCreateProgress(forBookId: book.id)
    }

    /// Generate questions for a specific level
    private func generateQuestions(for level: GameLevel?) {
        var generatedQuestions: [GameQuestion] = []

        // Determine which words to use
        let wordsToUse: [Word]
        if let level = level {
            // Use words for this specific level
            let levelWordIds = Set(level.wordIds)
            wordsToUse = allWords.filter { levelWordIds.contains($0.id) }
        } else {
            // Use random words for practice
            wordsToUse = Array(allWords.shuffled().prefix(10))
        }

        // Create questions for each word with different types
        for (index, word) in wordsToUse.enumerated() {
            let questionType = questionTypeForIndex(index)
            let question = createQuestion(from: word, type: questionType)
            generatedQuestions.append(question)
        }

        questions = generatedQuestions.shuffled()
    }

    /// Determine question type based on position (for variety)
    private func questionTypeForIndex(_ index: Int) -> QuestionType {
        // Mix question types: choice, spelling, listening
        let types: [QuestionType] = [.choice, .choice, .spelling, .listening]
        return types[index % types.count]
    }

    /// Create a question for a word
    private func createQuestion(from word: Word, type: QuestionType) -> GameQuestion {
        switch type {
        case .choice:
            // Generate wrong options from similar words
            let wrongOptions = generateWrongOptions(for: word, count: 3)
            let options = ([word.meaning] + wrongOptions).shuffled()

            return GameQuestion(
                word: word,
                questionType: .choice,
                options: options,
                correctAnswer: word.meaning
            )

        case .spelling:
            return GameQuestion(
                word: word,
                questionType: .spelling,
                correctAnswer: word.word
            )

        case .listening:
            return GameQuestion(
                word: word,
                questionType: .listening,
                correctAnswer: word.word
            )
        }
    }

    /// Generate wrong options for choice questions
    private func generateWrongOptions(for word: Word, count: Int) -> [String] {
        // Get random words that aren't the correct one
        let otherWords = allWords.filter { $0.id != word.id }
        let shuffled = otherWords.shuffled()

        return Array(shuffled.prefix(count).map { $0.meaning })
    }

    // MARK: - Answer Handling
    /// Submit an answer for the current question
    func submitAnswer(_ answer: String) async {
        guard var question = currentQuestion else { return }

        question.isAnswered = true
        question.userAnswer = answer

        let isCorrect = answer.lowercased().trimmingCharacters(in: .whitespaces)
            == question.correctAnswer.lowercased().trimmingCharacters(in: .whitespaces)

        question.isCorrect = isCorrect

        // Update question in array
        questions[currentQuestionIndex] = question

        // Update scores
        if isCorrect {
            correctCount += 1
            score += 10

            // Update word mastery
            await updateWordMastery(word: question.word, correct: true)
        } else {
            wrongCount += 1

            // Update word mastery
            await updateWordMastery(word: question.word, correct: false)
        }

        // Record learning
        await recordLearning(for: question, answer: answer, isCorrect: isCorrect)

        // Move to next question or end game (non-blocking)
        advanceQuestion()
    }

    /// Move to the next question or end the game
    /// Callers should use the returned delay hint to coordinate UI feedback animations.
    /// The VM itself no longer blocks with sleep — it immediately updates state and lets
    /// the View decide how/whether to animate the transition.
    private func advanceQuestion() {
        if currentQuestionIndex + 1 < questions.count {
            currentQuestionIndex += 1
            // Reset the per-question timer for the newly shown question
            currentQuestionStartTime = Date()
        } else {
            Task {
                await endGame()
            }
        }
    }

    /// End the game and calculate results
    private func endGame() async {
        isSavingProgress = true  // Block navigation until DB write completes
        isGameActive = false
        isGameCompleted = true

        // Calculate stars
        let accuracy = totalQuestions > 0 ? Double(correctCount) / Double(totalQuestions) * 100 : 0

        if accuracy >= 100 {
            starsEarned = 3
        } else if accuracy >= 80 {
            starsEarned = 2
        } else if accuracy >= 60 {
            starsEarned = 1
        } else {
            starsEarned = 0
        }

        // Create game result
        gameResult = GameResult(
            bookId: currentBook?.id ?? "",
            levelNumber: currentLevel?.levelNumber ?? 1,
            totalQuestions: totalQuestions,
            correctCount: correctCount,
            wrongCount: wrongCount,
            score: score,
            starsEarned: starsEarned,
            accuracy: accuracy,
            isPassed: accuracy >= 60
        )

        // Update progress
        await updateProgress()
        isSavingProgress = false  // Unblock navigation
    }

    /// Update word mastery level based on answer result
    private func updateWordMastery(word: Word, correct: Bool) async {
        var updatedWord = word

        if correct {
            updatedWord.masteryLevel = min(5, word.masteryLevel + 1)
            updatedWord.wrongCount = 0
        } else {
            updatedWord.masteryLevel = max(0, word.masteryLevel - 1)
            updatedWord.wrongCount = word.wrongCount + 1
        }

        updatedWord.lastReviewedAt = Date()

        try? database.updateWord(updatedWord)
    }

    /// Record learning for analytics
    private func recordLearning(for question: GameQuestion, answer: String, isCorrect: Bool) async {
        guard let book = currentBook else { return }

        // Measure time from when this specific question was shown to the user
        let answerTime: Int
        if let start = currentQuestionStartTime {
            answerTime = Int(Date().timeIntervalSince(start) * 1000)
        } else {
            answerTime = 0
        }

        let record = LearningRecord(
            wordId: question.word.id,
            bookId: book.id,
            result: isCorrect,
            questionType: question.questionType,
            answerTimeMs: answerTime
        )

        try? database.createLearningRecord(record)
    }

    /// Update game progress
    private func updateProgress() async {
        guard let book = currentBook, let result = gameResult, let level = currentLevel else { return }

        do {
            var progress = try database.fetchOrCreateProgress(forBookId: book.id)

            progress.totalCorrect += result.correctCount
            progress.totalAnswered += result.totalQuestions
            progress.starsEarned += result.starsEarned

            // Record this level's completion (always record, even if failed)
            let levelRecord = LevelRecord(
                bookId: book.id,
                chapter: level.chapter,
                stage: level.isBossLevel ? 4 : level.stage,
                isPassed: result.isPassed,
                starsEarned: result.starsEarned
            )
            try database.saveLevelRecord(levelRecord)

            // Advance to next level if passed
            if result.isPassed {
                if level.isBossLevel {
                    // Boss passed, move to next chapter
                    progress.currentChapter += 1
                    progress.currentStage = 1
                } else if level.stage == 3 {
                    // Stage 3 passed, next is boss
                    progress.currentStage = 1
                } else {
                    // Normal stage progression
                    progress.currentStage = level.stage + 1
                }
            }

            try database.updateGameProgress(progress)
        } catch {
            print("Failed to update progress: \(error)")
        }
    }

    // MARK: - Level Generation
    /// Generate levels for a word book based on word count
    func generateLevels(for book: WordBook) -> [GameLevel] {
        do {
            let words = try database.fetchWords(forBookId: book.id)
            return generateLevelsFromWords(words, bookId: book.id)
        } catch {
            print("Failed to generate levels: \(error)")
            return []
        }
    }

    /// Generate game levels from a list of words
    private func generateLevelsFromWords(_ words: [Word], bookId: String) -> [GameLevel] {
        var levels: [GameLevel] = []
        let wordsPerStage = 10
        let stagesPerChapter = 3

        let wordChunks = words.chunked(into: wordsPerStage)

        for (index, chunk) in wordChunks.enumerated() {
            let chapter = (index / stagesPerChapter) + 1
            let stage = (index % stagesPerChapter) + 1

            let isBossLevel = stage == stagesPerChapter && !chunk.isEmpty

            let level = GameLevel(
                id: index + 1,
                bookId: bookId,
                chapter: chapter,
                stage: isBossLevel ? 3 : stage,
                name: isBossLevel ? "Boss 挑战 - 第\(chapter)章" : "第\(chapter)章 第\(stage)关",
                wordIds: chunk.map { $0.id },
                passingScore: 80,
                isBossLevel: isBossLevel
            )

            levels.append(level)

            // Add boss level after stage 3
            if isBossLevel {
                let bossLevel = GameLevel(
                    id: index + 2,
                    bookId: bookId,
                    chapter: chapter,
                    stage: 4,  // Boss is virtual stage 4
                    name: "Boss 挑战 - 第\(chapter)章",
                    wordIds: chunk.map { $0.id },  // Boss uses same words but mixed types
                    passingScore: 80,
                    isBossLevel: true
                )
                levels.append(bossLevel)
            }
        }

        return levels
    }
}

// MARK: - Supporting Types
struct GameResult {
    let bookId: String
    let levelNumber: Int
    let totalQuestions: Int
    let correctCount: Int
    let wrongCount: Int
    let score: Int
    let starsEarned: Int
    let accuracy: Double
    let isPassed: Bool
}

// MARK: - Array Extension
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
