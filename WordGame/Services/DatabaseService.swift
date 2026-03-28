import Foundation
import SQLite
import os

/// DatabaseService manages all SQLite database operations
/// Singleton pattern ensures single database connection throughout the app
final class DatabaseService: ObservableObject {
    static let shared = DatabaseService()
    private let logger = Logger(subsystem: "com.wordgame.database", category: "DatabaseService")

    private var db: Connection?
    let dbPath: String

    // MARK: - Table Definitions
    private let wordBooks = Table("word_books")
    private let words = Table("words")
    private let gameProgress = Table("game_progress")
    private let learningRecords = Table("learning_records")
    private let levelRecords = Table("level_records")
    private let reviewLevelRecords = Table("review_level_records")

    // MARK: - WordBooks Columns
    private let wbId = Expression<String>("id")
    private let wbName = Expression<String>("name")
    private let wbDescription = Expression<String?>("description")
    private let wbWordCount = Expression<Int>("word_count")
    private let wbIsPreset = Expression<Bool>("is_preset")
    private let wbCreatedAt = Expression<Double>("created_at")
    private let wbUpdatedAt = Expression<Double>("updated_at")

    // MARK: - Words Columns
    private let wId = Expression<String>("id")
    private let wBookId = Expression<String>("book_id")
    private let wWord = Expression<String>("word")
    private let wPhonetic = Expression<String?>("phonetic")
    private let wMeaning = Expression<String>("meaning")
    private let wSentence = Expression<String?>("sentence")
    private let wSentenceTranslation = Expression<String?>("sentence_translation")
    private let wAudioUrl = Expression<String?>("audio_url")
    private let wMasteryLevel = Expression<Int>("mastery_level")
    private let wWrongCount = Expression<Int>("wrong_count")
    private let wLastReviewedAt = Expression<Double?>("last_reviewed_at")
    private let wCreatedAt = Expression<Double>("created_at")

    // MARK: - GameProgress Columns
    private let gpId = Expression<String>("id")
    private let gpBookId = Expression<String>("book_id")
    private let gpCurrentChapter = Expression<Int>("current_chapter")
    private let gpCurrentStage = Expression<Int>("current_stage")
    private let gpStarsEarned = Expression<Int>("stars_earned")
    private let gpTotalCorrect = Expression<Int>("total_correct")
    private let gpTotalAnswered = Expression<Int>("total_answered")
    private let gpIsCompleted = Expression<Bool>("is_completed")
    private let gpUpdatedAt = Expression<Double>("updated_at")
    private let gpLastPassedBossChapter = Expression<Int>("last_passed_boss_chapter")

    // MARK: - LearningRecords Columns
    private let lrId = Expression<String>("id")
    private let lrWordId = Expression<String>("word_id")
    private let lrBookId = Expression<String>("book_id")
    private let lrResult = Expression<Bool>("result")
    private let lrQuestionType = Expression<String>("question_type")
    private let lrAnswerTimeMs = Expression<Int>("answer_time_ms")
    private let lrCreatedAt = Expression<Double>("created_at")

    // MARK: - LevelRecords Columns
    private let lvlId = Expression<String>("id")
    private let lvlBookId = Expression<String>("book_id")
    private let lvlChapter = Expression<Int>("chapter")
    private let lvlStage = Expression<Int>("stage")
    private let lvlIsPassed = Expression<Bool>("is_passed")
    private let lvlStarsEarned = Expression<Int>("stars_earned")
    private let lvlCompletedAt = Expression<Double>("completed_at")

    // MARK: - ReviewLevelRecords Columns
    private let rlrId = Expression<String>("id")
    private let rlrBookId = Expression<String>("book_id")
    private let rlrLevelId = Expression<Int>("level_id")
    private let rlrCompletedAt = Expression<Double>("completed_at")

    private init() {
        // Setup database path in Application Support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("WordGame", isDirectory: true)

        // Create directory if not exists
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        dbPath = appFolder.appendingPathComponent("wordgame.db").path

        do {
            db = try Connection(dbPath)
            createTables()
            migrateTablesIfNeeded()
        } catch {
            logger.error("Database connection failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Table Migration
    /// Migrate existing tables to add new columns
    private func migrateTablesIfNeeded() {
        guard let db = db else { return }

        do {
            let tableInfo = try db.prepare("PRAGMA table_info(words)")
            var existingColumns = Set<String>()
            for row in tableInfo {
                if let name = row[1] as? String {
                    existingColumns.insert(name)
                }
            }

            if !existingColumns.contains("sentence_translation") {
                try db.run("ALTER TABLE words ADD COLUMN sentence_translation TEXT")
                logger.info("Migrated words table: added sentence_translation column")
            }

            if !existingColumns.contains("audio_url") {
                try db.run("ALTER TABLE words ADD COLUMN audio_url TEXT")
                logger.info("Migrated words table: added audio_url column")
            }

            // Migrate game_progress table for lastPassedBossChapter
            let progressTableInfo = try db.prepare("PRAGMA table_info(game_progress)")
            var progressColumns = Set<String>()
            for row in progressTableInfo {
                if let name = row[1] as? String {
                    progressColumns.insert(name)
                }
            }
            if !progressColumns.contains("last_passed_boss_chapter") {
                try db.run("ALTER TABLE game_progress ADD COLUMN last_passed_boss_chapter INTEGER DEFAULT 0")
                logger.info("Migrated game_progress table: added last_passed_boss_chapter column")
            }
        } catch {
            logger.error("Migration failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Table Creation
    private func createTables() {
        guard let db = db else { return }

        do {
            // WordBooks table
            try db.run(wordBooks.create(ifNotExists: true) { t in
                t.column(wbId, primaryKey: true)
                t.column(wbName)
                t.column(wbDescription)
                t.column(wbWordCount, defaultValue: 0)
                t.column(wbIsPreset, defaultValue: false)
                t.column(wbCreatedAt)
                t.column(wbUpdatedAt)
            })

            // Words table
            try db.run(words.create(ifNotExists: true) { t in
                t.column(wId, primaryKey: true)
                t.column(wBookId)
                t.column(wWord)
                t.column(wPhonetic)
                t.column(wMeaning)
                t.column(wSentence)
                t.column(wSentenceTranslation)
                t.column(wAudioUrl)
                t.column(wMasteryLevel, defaultValue: 0)
                t.column(wWrongCount, defaultValue: 0)
                t.column(wLastReviewedAt)
                t.column(wCreatedAt)
                t.foreignKey(wBookId, references: wordBooks, wbId, delete: .cascade)
            })

            // GameProgress table
            try db.run(gameProgress.create(ifNotExists: true) { t in
                t.column(gpId, primaryKey: true)
                t.column(gpBookId)
                t.column(gpCurrentChapter, defaultValue: 1)
                t.column(gpCurrentStage, defaultValue: 1)
                t.column(gpStarsEarned, defaultValue: 0)
                t.column(gpTotalCorrect, defaultValue: 0)
                t.column(gpTotalAnswered, defaultValue: 0)
                t.column(gpIsCompleted, defaultValue: false)
                t.column(gpUpdatedAt)
                t.foreignKey(gpBookId, references: wordBooks, wbId, delete: .cascade)
            })

            // LearningRecords table
            try db.run(learningRecords.create(ifNotExists: true) { t in
                t.column(lrId, primaryKey: true)
                t.column(lrWordId)
                t.column(lrBookId)
                t.column(lrResult)
                t.column(lrQuestionType)
                t.column(lrAnswerTimeMs, defaultValue: 0)
                t.column(lrCreatedAt)
                t.foreignKey(lrWordId, references: words, wId, delete: .cascade)
            })

            // LevelRecords table (per-level completion tracking)
            try db.run(levelRecords.create(ifNotExists: true) { t in
                t.column(lvlId, primaryKey: true)
                t.column(lvlBookId)
                t.column(lvlChapter)
                t.column(lvlStage)
                t.column(lvlIsPassed, defaultValue: false)
                t.column(lvlStarsEarned, defaultValue: 0)
                t.column(lvlCompletedAt)
            })

            // ReviewLevelRecords table (per review-level completion tracking)
            try db.run(reviewLevelRecords.create(ifNotExists: true) { t in
                t.column(rlrId, primaryKey: true)
                t.column(rlrBookId)
                t.column(rlrLevelId)
                t.column(rlrCompletedAt)
            })

            // Create indexes for better query performance
            try db.run(words.createIndex(wBookId, ifNotExists: true))
            try db.run(learningRecords.createIndex(lrWordId, ifNotExists: true))
            try db.run(learningRecords.createIndex(lrBookId, ifNotExists: true))
            try db.run(reviewLevelRecords.createIndex(rlrBookId, ifNotExists: true))

        } catch {
            logger.error("Table creation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - WordBook Operations
    func createWordBook(_ book: WordBook) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let insert = wordBooks.insert(
            wbId <- book.id,
            wbName <- book.name,
            wbDescription <- book.description,
            wbWordCount <- book.wordCount,
            wbIsPreset <- book.isPreset,
            wbCreatedAt <- book.createdAt.timeIntervalSince1970,
            wbUpdatedAt <- book.updatedAt.timeIntervalSince1970
        )

        try db.run(insert)
    }

    func fetchAllWordBooks() throws -> [WordBook] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var result: [WordBook] = []

        for row in try db.prepare(wordBooks.order(wbCreatedAt.desc)) {
            let book = WordBook(
                id: row[wbId],
                name: row[wbName],
                description: row[wbDescription],
                wordCount: row[wbWordCount],
                isPreset: row[wbIsPreset],
                createdAt: Date(timeIntervalSince1970: row[wbCreatedAt]),
                updatedAt: Date(timeIntervalSince1970: row[wbUpdatedAt])
            )
            result.append(book)
        }

        return result
    }

    func fetchWordBook(byId id: String) throws -> WordBook? {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = wordBooks.filter(wbId == id)

        guard let row = try db.pluck(query) else { return nil }

        return WordBook(
            id: row[wbId],
            name: row[wbName],
            description: row[wbDescription],
            wordCount: row[wbWordCount],
            isPreset: row[wbIsPreset],
            createdAt: Date(timeIntervalSince1970: row[wbCreatedAt]),
            updatedAt: Date(timeIntervalSince1970: row[wbUpdatedAt])
        )
    }

    func updateWordBook(_ book: WordBook) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = wordBooks.filter(wbId == book.id)
        try db.run(query.update(
            wbName <- book.name,
            wbDescription <- book.description,
            wbWordCount <- book.wordCount,
            wbUpdatedAt <- Date().timeIntervalSince1970
        ))
    }

    func deleteWordBook(byId id: String) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        // Delete associated words first (foreign key cascade should handle this, but explicit for safety)
        let wordsQuery = words.filter(wBookId == id)
        try db.run(wordsQuery.delete())

        let query = wordBooks.filter(wbId == id)
        try db.run(query.delete())
    }

    func checkPresetVocabularyExists(_ preset: PresetVocabulary) throws -> Bool {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = wordBooks.filter(wbName == preset.displayName && wbIsPreset == true)
        return try db.pluck(query) != nil
    }

    /// Fetch a preset vocabulary book by its PresetVocabulary type.
    /// Returns nil if not found.
    func fetchPresetVocabulary(_ preset: PresetVocabulary) throws -> WordBook? {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = wordBooks.filter(wbName == preset.displayName && wbIsPreset == true)
        guard let row = try db.pluck(query) else { return nil }

        return WordBook(
            id: row[wbId],
            name: row[wbName],
            description: row[wbDescription],
            wordCount: row[wbWordCount],
            isPreset: row[wbIsPreset],
            createdAt: Date(timeIntervalSince1970: row[wbCreatedAt]),
            updatedAt: Date(timeIntervalSince1970: row[wbUpdatedAt])
        )
    }

    // MARK: - Word Operations
    func createWord(_ word: Word) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let insert = words.insert(
            wId <- word.id,
            wBookId <- word.bookId,
            wWord <- word.word,
            wPhonetic <- word.phonetic,
            wMeaning <- word.meaning,
            wSentence <- word.sentence,
            wSentenceTranslation <- word.sentenceTranslation,
            wAudioUrl <- word.audioUrl,
            wMasteryLevel <- word.masteryLevel,
            wWrongCount <- word.wrongCount,
            wLastReviewedAt <- word.lastReviewedAt?.timeIntervalSince1970,
            wCreatedAt <- word.createdAt.timeIntervalSince1970
        )

        try db.run(insert)

        // Atomically increment word_count
        try db.run("UPDATE word_books SET word_count = word_count + 1, updated_at = ? WHERE id = ?",
                   Date().timeIntervalSince1970, word.bookId)
    }

    func createWords(_ wordList: [Word]) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        try db.transaction {
            for word in wordList {
                try createWord(word)
            }
        }
    }

    func fetchWords(forBookId bookId: String) throws -> [Word] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var result: [Word] = []
        let query = words.filter(wBookId == bookId).order(wCreatedAt.asc)

        for row in try db.prepare(query) {
            let word = Word(
                id: row[wId],
                bookId: row[wBookId],
                word: row[wWord],
                phonetic: row[wPhonetic],
                meaning: row[wMeaning],
                sentence: row[wSentence],
                sentenceTranslation: row[wSentenceTranslation],
                audioUrl: row[wAudioUrl],
                masteryLevel: row[wMasteryLevel],
                wrongCount: row[wWrongCount],
                lastReviewedAt: row[wLastReviewedAt].map { Date(timeIntervalSince1970: $0) },
                createdAt: Date(timeIntervalSince1970: row[wCreatedAt])
            )
            result.append(word)
        }

        return result
    }

    func fetchWord(byId id: String) throws -> Word? {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = words.filter(wId == id)

        guard let row = try db.pluck(query) else { return nil }

        return Word(
            id: row[wId],
            bookId: row[wBookId],
            word: row[wWord],
            phonetic: row[wPhonetic],
            meaning: row[wMeaning],
            sentence: row[wSentence],
            sentenceTranslation: row[wSentenceTranslation],
            audioUrl: row[wAudioUrl],
            masteryLevel: row[wMasteryLevel],
            wrongCount: row[wWrongCount],
            lastReviewedAt: row[wLastReviewedAt].map { Date(timeIntervalSince1970: $0) },
            createdAt: Date(timeIntervalSince1970: row[wCreatedAt])
        )
    }

    func updateWord(_ word: Word) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = words.filter(wId == word.id)
        try db.run(query.update(
            wWord <- word.word,
            wPhonetic <- word.phonetic,
            wMeaning <- word.meaning,
            wSentence <- word.sentence,
            wSentenceTranslation <- word.sentenceTranslation,
            wAudioUrl <- word.audioUrl,
            wMasteryLevel <- word.masteryLevel,
            wWrongCount <- word.wrongCount,
            wLastReviewedAt <- word.lastReviewedAt?.timeIntervalSince1970
        ))
    }

    func deleteWord(byId id: String) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        // Fetch word to get its bookId before deleting
        guard let word = try fetchWord(byId: id) else { return }

        let query = words.filter(wId == id)
        try db.run(query.delete())

        // Atomically decrement word_count
        try db.run("UPDATE word_books SET word_count = MAX(0, word_count - 1), updated_at = ? WHERE id = ?",
                   Date().timeIntervalSince1970, word.bookId)
    }

    func fetchRandomWords(forBookId bookId: String, count: Int, excludingIds: [String] = []) throws -> [Word] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var query = words.filter(wBookId == bookId)

        if !excludingIds.isEmpty {
            query = query.filter(!excludingIds.contains(wId))
        }

        query = query.order(Expression<Int>.random()).limit(count)

        var result: [Word] = []

        for row in try db.prepare(query) {
            let word = Word(
                id: row[wId],
                bookId: row[wBookId],
                word: row[wWord],
                phonetic: row[wPhonetic],
                meaning: row[wMeaning],
                sentence: row[wSentence],
                sentenceTranslation: row[wSentenceTranslation],
                audioUrl: row[wAudioUrl],
                masteryLevel: row[wMasteryLevel],
                wrongCount: row[wWrongCount],
                lastReviewedAt: row[wLastReviewedAt].map { Date(timeIntervalSince1970: $0) },
                createdAt: Date(timeIntervalSince1970: row[wCreatedAt])
            )
            result.append(word)
        }

        return result
    }

    // MARK: - GameProgress Operations
    func fetchOrCreateProgress(forBookId bookId: String) throws -> GameProgress {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = gameProgress.filter(gpBookId == bookId)

        if let row = try db.pluck(query) {
            return GameProgress(
                id: row[gpId],
                bookId: row[gpBookId],
                currentChapter: row[gpCurrentChapter],
                currentStage: row[gpCurrentStage],
                starsEarned: row[gpStarsEarned],
                totalCorrect: row[gpTotalCorrect],
                totalAnswered: row[gpTotalAnswered],
                isCompleted: row[gpIsCompleted],
                updatedAt: Date(timeIntervalSince1970: row[gpUpdatedAt]),
                lastPassedBossChapter: row[gpLastPassedBossChapter]
            )
        }

        // Create new progress
        let progress = GameProgress(bookId: bookId)
        try createGameProgress(progress)
        return progress
    }

    func createGameProgress(_ progress: GameProgress) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let insert = gameProgress.insert(
            gpId <- progress.id,
            gpBookId <- progress.bookId,
            gpCurrentChapter <- progress.currentChapter,
            gpCurrentStage <- progress.currentStage,
            gpStarsEarned <- progress.starsEarned,
            gpTotalCorrect <- progress.totalCorrect,
            gpTotalAnswered <- progress.totalAnswered,
            gpIsCompleted <- progress.isCompleted,
            gpUpdatedAt <- progress.updatedAt.timeIntervalSince1970,
            gpLastPassedBossChapter <- progress.lastPassedBossChapter
        )

        try db.run(insert)
    }

    func updateGameProgress(_ progress: GameProgress) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = gameProgress.filter(gpId == progress.id)
        try db.run(query.update(
            gpCurrentChapter <- progress.currentChapter,
            gpCurrentStage <- progress.currentStage,
            gpStarsEarned <- progress.starsEarned,
            gpTotalCorrect <- progress.totalCorrect,
            gpTotalAnswered <- progress.totalAnswered,
            gpIsCompleted <- progress.isCompleted,
            gpUpdatedAt <- Date().timeIntervalSince1970,
            gpLastPassedBossChapter <- progress.lastPassedBossChapter
        ))
    }

    // MARK: - LearningRecord Operations
    func createLearningRecord(_ record: LearningRecord) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let insert = learningRecords.insert(
            lrId <- record.id,
            lrWordId <- record.wordId,
            lrBookId <- record.bookId,
            lrResult <- record.result,
            lrQuestionType <- record.questionType.rawValue,
            lrAnswerTimeMs <- record.answerTimeMs,
            lrCreatedAt <- record.createdAt.timeIntervalSince1970
        )

        try db.run(insert)
    }

    func fetchLearningRecords(forWordId wordId: String) throws -> [LearningRecord] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var result: [LearningRecord] = []
        let query = learningRecords.filter(lrWordId == wordId).order(lrCreatedAt.desc)

        for row in try db.prepare(query) {
            let record = LearningRecord(
                id: row[lrId],
                wordId: row[lrWordId],
                bookId: row[lrBookId],
                result: row[lrResult],
                questionType: QuestionType(rawValue: row[lrQuestionType]) ?? .choice,
                answerTimeMs: row[lrAnswerTimeMs],
                createdAt: Date(timeIntervalSince1970: row[lrCreatedAt])
            )
            result.append(record)
        }

        return result
    }

    // MARK: - LevelRecord Operations

    /// Fetch the completion record for a specific level.
    func fetchLevelRecord(bookId: String, chapter: Int, stage: Int) throws -> LevelRecord? {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = levelRecords.filter(
            lvlBookId == bookId && lvlChapter == chapter && lvlStage == stage
        )
        guard let row = try db.pluck(query) else { return nil }

        return LevelRecord(
            id: row[lvlId],
            bookId: row[lvlBookId],
            chapter: row[lvlChapter],
            stage: row[lvlStage],
            isPassed: row[lvlIsPassed],
            starsEarned: row[lvlStarsEarned],
            completedAt: Date(timeIntervalSince1970: row[lvlCompletedAt])
        )
    }

    /// Fetch all level completion records for a word book.
    func fetchAllLevelRecords(forBookId bookId: String) throws -> [LevelRecord] {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var result: [LevelRecord] = []
        let query = levelRecords.filter(lvlBookId == bookId).order(lvlChapter.asc, lvlStage.asc)

        for row in try db.prepare(query) {
            let record = LevelRecord(
                id: row[lvlId],
                bookId: row[lvlBookId],
                chapter: row[lvlChapter],
                stage: row[lvlStage],
                isPassed: row[lvlIsPassed],
                starsEarned: row[lvlStarsEarned],
                completedAt: Date(timeIntervalSince1970: row[lvlCompletedAt])
            )
            result.append(record)
        }

        return result
    }

    /// Save or update a level completion record.
    /// If a record for this level already exists, update it only if the new result is better.
    func saveLevelRecord(_ record: LevelRecord) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = levelRecords.filter(
            lvlBookId == record.bookId && lvlChapter == record.chapter && lvlStage == record.stage
        )

        if let existing = try db.pluck(query) {
            let existingStars = existing[lvlStarsEarned]
            let existingPassed = existing[lvlIsPassed]
            let shouldUpdate = record.starsEarned > existingStars || (!existingPassed && record.isPassed)

            if shouldUpdate {
                try db.run(query.update(
                    lvlIsPassed <- (existingPassed || record.isPassed),
                    lvlStarsEarned <- max(existingStars, record.starsEarned),
                    lvlCompletedAt <- record.completedAt.timeIntervalSince1970
                ))
            }
        } else {
            // Insert new record
            try db.run(levelRecords.insert(
                lvlId <- record.id,
                lvlBookId <- record.bookId,
                lvlChapter <- record.chapter,
                lvlStage <- record.stage,
                lvlIsPassed <- record.isPassed,
                lvlStarsEarned <- record.starsEarned,
                lvlCompletedAt <- record.completedAt.timeIntervalSince1970
            ))
        }
    }

    // MARK: - ReviewLevelRecord Operations

    /// Save a completed review level record. Idempotent — replaces if already exists.
    func saveReviewLevelRecord(bookId: String, levelId: Int) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }

        let query = reviewLevelRecords.filter(rlrBookId == bookId && rlrLevelId == levelId)
        if try db.pluck(query) != nil {
            // Already recorded, just update timestamp
            try db.run(query.update(rlrCompletedAt <- Date().timeIntervalSince1970))
        } else {
            try db.run(reviewLevelRecords.insert(
                rlrId <- UUID().uuidString,
                rlrBookId <- bookId,
                rlrLevelId <- levelId,
                rlrCompletedAt <- Date().timeIntervalSince1970
            ))
        }
    }

    /// Fetch all completed review level IDs for a book.
    func fetchCompletedReviewLevelIds(bookId: String) throws -> Set<Int> {
        guard let db = db else { throw DatabaseError.connectionFailed }

        var result = Set<Int>()
        let query = reviewLevelRecords.filter(rlrBookId == bookId)
        for row in try db.prepare(query) {
            result.insert(row[rlrLevelId])
        }
        return result
    }

    /// Reset all game progress, level records, and learning records for a specific book.
    /// Preset vocabularies are also reset (user progress cleared, words remain).
    func resetAllProgress(forBookId bookId: String) throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        try db.run(learningRecords.filter(lrBookId == bookId).delete())
        try db.run(gameProgress.filter(gpBookId == bookId).delete())
        try db.run(levelRecords.filter(lvlBookId == bookId).delete())
        try db.run(reviewLevelRecords.filter(rlrBookId == bookId).delete())
    }

    /// Reset all progress for ALL books (used by settings reset).
    /// Also resets word mastery levels and wrong counts so words are fresh.
    func resetAllProgressGlobally() throws {
        guard let db = db else { throw DatabaseError.connectionFailed }
        try db.run(learningRecords.delete())
        try db.run(gameProgress.delete())
        try db.run(levelRecords.delete())
        // Reset word mastery so next game starts clean
        try db.run(words.update(
            wMasteryLevel <- 0,
            wWrongCount <- 0,
            wLastReviewedAt <- (nil as Double?)
        ))
    }
}

// MARK: - Database Errors
enum DatabaseError: Error, LocalizedError {
    case connectionFailed
    case insertFailed
    case updateFailed
    case deleteFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "数据库连接失败"
        case .insertFailed:
            return "数据插入失败"
        case .updateFailed:
            return "数据更新失败"
        case .deleteFailed:
            return "数据删除失败"
        case .notFound:
            return "数据未找到"
        }
    }
}
