import Foundation
import SwiftUI
import os

/// ViewModel for game/learning session management
@MainActor
final class GameViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.wordgame.game", category: "GameViewModel")
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
    /// Maps chapter → [wordId] for generating contextually-relevant wrong options
    private var chapterWordIds: [Int: Set<String>] = [:]
    /// Time when the current question was shown to the user (for accurate answer time tracking)
    private var currentQuestionStartTime: Date?
    private let database = DatabaseService.shared
    /// When true, the game is in review mode (no learning phase, uses provided word set)
    private var isReviewMode = false
    /// Pool of words to use when in review mode (set by startReviewGame)
    private var reviewWordsPool: [Word] = []

    // MARK: - Computed Properties
    /// Words available for the current level's pre-game learning phase.
    /// Returns words belonging to the current level (or all words for practice mode),
    /// limited to the same cap as generateQuestions().
    var learningWords: [Word] {
        guard let level = currentLevel else {
            let cap = UserDefaults.standard.integer(forKey: "questionsPerRound")
            return Array(allWords.shuffled().prefix(cap > 0 ? cap : 10))
        }
        let cap = UserDefaults.standard.integer(forKey: "questionsPerRound")
        let levelWordIds = Set(level.wordIds)
        let filtered = allWords.filter { levelWordIds.contains($0.id) }
        return Array(filtered.prefix(cap > 0 ? cap : filtered.count))
    }

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

    /// Current passing threshold based on selected difficulty
    var passingThreshold: Int {
        guard let rawValue = UserDefaults.standard.string(forKey: "gameDifficulty"),
              let difficulty = GameDifficulty(rawValue: rawValue) else {
            return 60  // Default to medium
        }
        return difficulty.passingThreshold
    }

    // MARK: - Game Lifecycle
    /// Start a new game for the given word book.
    /// Clears progress/state immediately but keeps the previous questions visible
    /// until fresh ones are ready (prevents UI flicker on restart).
    func startGame(for book: WordBook, level: GameLevel? = nil) async {
        currentBook = book
        currentLevel = level

        // Reset score/progress state immediately
        currentQuestionIndex = 0
        score = 0
        correctCount = 0
        wrongCount = 0
        isGameActive = false   // Briefly false while generating
        isGameCompleted = false
        gameResult = nil
        starsEarned = 0
        // Note: currentQuestionStartTime is set when the first question is actually shown

        // Load all words for the book
        do {
            allWords = try database.fetchWords(forBookId: book.id)
        } catch {
            logger.error("Failed to load words: \(error.localizedDescription)")
            return
        }

        // Check if we have words
        guard !allWords.isEmpty else {
            logger.warning("No words found in book: \(book.name)")
            // Clear questions so empty state shows instead of stale content
            questions = []
            return
        }

        // Build chapter → wordIds map from level definition (used for wrong options)
        if let lvl = level {
            chapterWordIds = buildChapterWordIds(for: lvl, allWords: allWords)
        } else {
            // Practice mode: group all words into a single synthetic chapter
            chapterWordIds = [1: Set(allWords.map { $0.id })]
        }

        // Generate questions BEFORE clearing old ones
        // This ensures GameView always has questions to display during the transition
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

    /// Start a review game session for a specific review level.
    /// In review mode there is no learning phase — questions begin immediately.
    func startReviewGame(for book: WordBook, level: GameLevel, reviewWords: [Word]) async {
        isReviewMode = true
        reviewWordsPool = reviewWords
        await startGame(for: book, level: level)
        isReviewMode = false
        reviewWordsPool = []
    }

    /// Generate questions for a specific level.
    /// Respects questionsPerRound from UserSettings (Bug 8 fix).
    private func generateQuestions(for level: GameLevel?) {
        var generatedQuestions: [GameQuestion] = []

        // Respect user setting for number of questions per round
        let questionsPerRound = UserDefaults.standard.integer(forKey: "questionsPerRound")
        let targetCount = questionsPerRound > 0 ? questionsPerRound : 10

        // Determine which words to use
        let wordsToUse: [Word]
        if let level = level {
            // In review mode, use the provided review word pool filtered by level.wordIds
            if !reviewWordsPool.isEmpty {
                let levelWordIds = Set(level.wordIds)
                wordsToUse = Array(reviewWordsPool.filter { levelWordIds.contains($0.id) }.prefix(targetCount))
            } else {
                let levelWordIds = Set(level.wordIds)
                let filtered = allWords.filter { levelWordIds.contains($0.id) }
                wordsToUse = Array(filtered.prefix(targetCount))
            }
        } else {
            // Use random words for practice, capped at questionsPerRound
            wordsToUse = Array(allWords.shuffled().prefix(targetCount))
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

    /// Generate wrong options for choice questions.
    /// Prioritises words from the same chapter (or same word-book for practice mode)
    /// to make options feel contextually related rather than random.
    private func generateWrongOptions(for word: Word, count: Int) -> [String] {
        // Find the chapter this word belongs to in the current level
        let wordChapter = chapterWordIds.first { $0.value.contains(word.id) }?.key

        // Prefer words from the same chapter for semantically cohesive options
        var preferredPool: [Word] = []
        if let chapter = wordChapter, let chapterIds = chapterWordIds[chapter] {
            preferredPool = allWords.filter { chapterIds.contains($0.id) && $0.id != word.id }
        }

        // Fall back to any other word in the book if same-chapter pool is too small
        var fullPool = preferredPool.isEmpty ? allWords.filter { $0.id != word.id } : preferredPool
        fullPool.shuffle()

        return Array(fullPool.prefix(count).map { $0.meaning })
    }

    /// Build a chapter → wordIds map from the given level's structure.
    private func buildChapterWordIds(for level: GameLevel, allWords: [Word]) -> [Int: Set<String>] {
        // Use the same chunking logic as generateLevels to determine which chapter
        // each word belongs to, so wrong options can be drawn from the same chapter.
        var result: [Int: Set<String>] = [:]
        let wordsPerStage = 10
        let stagesPerChapter = 3
        let wordChunks = allWords.chunked(into: wordsPerStage)

        for (index, chunk) in wordChunks.enumerated() {
            let chapter = (index / stagesPerChapter) + 1
            let wordIds = Set(chunk.map { $0.id })
            result[chapter] = (result[chapter] ?? []) .union(wordIds)
        }
        return result
    }

    // MARK: - Answer Handling
    /// Submit an answer for the current question
    /// Note: does NOT auto-advance - caller decides when to move to next question
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

        // NOTE: no longer auto-advancing here - View controls navigation via goToNextQuestion()
    }

    /// Move to the next question or end the game
    /// Callers should use the returned delay hint to coordinate UI feedback animations.
    /// The VM itself no longer blocks with sleep — it immediately updates state and lets
    /// the View decide how/whether to animate the transition.
    private func advanceQuestion() {
        if currentQuestionIndex + 1 < questions.count {
            currentQuestionIndex += 1
            currentQuestionStartTime = Date()
        } else {
            Task {
                await endGame()
            }
        }
    }

    /// Go to the previous question (for navigation buttons)
    func goToPreviousQuestion() {
        guard currentQuestionIndex > 0 else { return }
        currentQuestionIndex -= 1
        currentQuestionStartTime = Date()
    }

    /// Go to the next question (for navigation buttons)
    func goToNextQuestion() {
        guard currentQuestionIndex + 1 < questions.count else { return }
        advanceQuestion()
    }

    /// End the game and calculate results
    func endGame() async {
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
            isPassed: accuracy >= Double(passingThreshold)
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

    /// Reset answer timing baseline when a question is actually presented to the user.
    func markCurrentQuestionPresented() {
        currentQuestionStartTime = Date()
    }

    /// Update game progress
    private func updateProgress() async {
        guard let book = currentBook, let result = gameResult, let level = currentLevel else { return }

        do {
            var progress = try database.fetchOrCreateProgress(forBookId: book.id)
            let existingRecord = try database.fetchLevelRecord(
                bookId: book.id,
                chapter: level.chapter,
                stage: level.isBossLevel ? 4 : level.stage
            )
            let previousBestStars = existingRecord?.starsEarned ?? 0

            progress.totalCorrect += result.correctCount
            progress.totalAnswered += result.totalQuestions

            // Record this level's completion (always record, even if failed)
            let levelRecord = LevelRecord(
                bookId: book.id,
                chapter: level.chapter,
                stage: level.isBossLevel ? 4 : level.stage,
                isPassed: result.isPassed,
                starsEarned: result.starsEarned
            )
            try database.saveLevelRecord(levelRecord)
            progress.starsEarned += max(0, result.starsEarned - previousBestStars)

            // Advance to next level if passed
            if result.isPassed {
                if level.isBossLevel {
                    // Boss passed: record which chapter's boss was cleared
                    progress.lastPassedBossChapter = max(progress.lastPassedBossChapter, level.chapter)
                    // Move to next chapter's stage 1
                    progress.currentChapter += 1
                    progress.currentStage = 1
                } else if level.stage == 3 {
                    // Stage 3 passed → next is the boss for this chapter (stage 4)
                    progress.currentStage = 4
                } else {
                    // Normal stage progression
                    progress.currentStage = level.stage + 1
                }
            }

            try database.updateGameProgress(progress)
        } catch {
            logger.error("Failed to update progress: \(error.localizedDescription)")
        }
    }

    // MARK: - Level Generation
    /// Find the first unlocked-but-not-passed level to continue from.
    /// Starts from gameProgress position and scans forward.
    func findCurrentLevel(for book: WordBook) async -> GameLevel? {
        do {
            let progress = try database.fetchOrCreateProgress(forBookId: book.id)
            let records = try database.fetchAllLevelRecords(forBookId: book.id)
            let levels = generateLevels(for: book)
            guard !levels.isEmpty else { return nil }

            // Build a set of passed (chapter, stage) keys
            var passedKeys: Set<String> = []
            for r in records where r.isPassed {
                passedKeys.insert("\(r.chapter)-\(r.stage)")
            }

            // Start scanning from the game's current position
            var chapter = progress.currentChapter
            var stage = progress.currentStage

            // Limit scan to avoid infinite loop (scan up to 50 levels)
            for _ in 0..<50 {
                let key = "\(chapter)-\(stage)"
                // If this level exists and hasn't been passed, it's the one to play
                if let level = levels.first(where: { $0.chapter == chapter && $0.stage == stage }), !passedKeys.contains(key) {
                    return level
                }
                // Advance to next level
                if stage < 4 {
                    stage += 1
                } else {
                    chapter += 1
                    stage = 1
                }
                // If we've gone beyond all generated levels, use the last one
                if chapter > (levels.map { $0.chapter }.max() ?? 1) {
                    return levels.last
                }
            }

            return levels.first
        } catch {
            return nil
        }
    }

    /// Generate levels for a word book based on word count
    func generateLevels(for book: WordBook) -> [GameLevel] {
        do {
            let words = try database.fetchWords(forBookId: book.id)
            return generateLevelsFromWords(words, bookId: book.id)
        } catch {
            logger.error("Failed to generate levels: \(error.localizedDescription)")
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

            // isLastStage is true for the 3rd stage in a chapter (the chapter-finisher).
            // The standalone Boss level uses stage=4 so its DB record is distinct from
            // regular stage 3 (stage=3). This keeps isStagePassed(ch,3) and isStagePassed(ch,4)
            // unambiguous: 3=regular stage 3 completion, 4=boss completion.
            let isLastStage = stage == stagesPerChapter && !chunk.isEmpty

            let level = GameLevel(
                id: levels.count + 1,
                bookId: bookId,
                chapter: chapter,
                stage: stage,
                name: "第\(chapter)章 第\(stage)关",
                wordIds: chunk.map { $0.id },
                passingScore: 80,
                isBossLevel: false
            )

            levels.append(level)

            // Add standalone Boss level as stage 4 (separate from regular stage 3)
            if isLastStage {
                let bossLevel = GameLevel(
                    id: levels.count + 1,
                    bookId: bookId,
                    chapter: chapter,
                    stage: 4,
                    name: "Boss 挑战 - 第\(chapter)章",
                    wordIds: chunk.map { $0.id },
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
