import Foundation
import os

/// Service for importing vocabulary from JSON files and CSV files
final class VocabImportService {
    static let shared = VocabImportService()
    private let logger = Logger(subsystem: "com.wordgame.vocab", category: "VocabImportService")

    private init() {}

    // MARK: - JSON Import
    /// Import vocabulary from a JSON file in the app bundle.
    ///
    /// Import semantics by preset type:
    /// - **CET-4**: Stable vocabulary. If already imported → skip (no update).
    /// - **high_school_3500**: Versioned. If already imported with same word count → skip;
    ///   if word count differs (new version detected) → replace with fresh import.
    func importPresetVocabulary(_ preset: PresetVocabulary) async throws {
        // Load vocabulary data from bundle (support both root and Vocabularies/ subdirectory).
        let url =
            Bundle.main.url(forResource: preset.rawValue, withExtension: "json", subdirectory: "Vocabularies") ??
            Bundle.main.url(forResource: preset.rawValue, withExtension: "json")

        guard let url else {
            throw VocabImportError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let vocabulary = try JSONDecoder().decode(VocabularyFile.self, from: data)
        let expectedWordCount = vocabulary.words.count

        // Check if this preset already exists in the database.
        if let existingBook = try DatabaseService.shared.fetchPresetVocabulary(preset) {
            switch preset {
            case .cet4:
                // CET-4: if word count matches, skip; otherwise re-import.
                if existingBook.wordCount == expectedWordCount {
                    logger.info("Preset '\(preset.displayName)' already up-to-date (\(expectedWordCount) words), skipping.")
                    return
                }
                // Word count mismatch (e.g. old stub with 20 words) → re-import.
                logger.info("Preset '\(preset.displayName)' word count mismatch (\(existingBook.wordCount) → \(expectedWordCount)), re-importing...")
                try DatabaseService.shared.deleteWordBook(byId: existingBook.id)

            case .primarySchool, .highSchool3500, .juniorHigh:
                // high_school_3500 is versioned — detect version change via word count.
                if existingBook.wordCount == expectedWordCount {
                    logger.info("Preset '\(preset.displayName)' already up-to-date (\(expectedWordCount) words), skipping.")
                    return
                }
                // Word count changed → delete old and re-import.
                logger.info("Preset '\(preset.displayName)' version changed (\(existingBook.wordCount) → \(expectedWordCount)), re-importing...")
                try DatabaseService.shared.deleteWordBook(byId: existingBook.id)
            }
        }

        // Create the word book and bulk-insert all words.
        let book = WordBook(
            name: preset.displayName,
            description: preset.description,
            wordCount: expectedWordCount,
            isPreset: true
        )
        try DatabaseService.shared.createWordBook(book)

        let words = vocabulary.words.map { vocabWord in
            Word(
                bookId: book.id,
                word: vocabWord.word,
                phonetic: vocabWord.phonetic,
                meaning: vocabWord.meaning,
                sentence: vocabWord.sentence,
                sentenceTranslation: vocabWord.sentenceTranslation
            )
        }
        try DatabaseService.shared.createWords(words)
    }

    /// Initialize all preset vocabularies
    func initializePresetVocabularies() async {
        for preset in PresetVocabulary.allCases {
            do {
                try await importPresetVocabulary(preset)
                logger.info("Imported vocabulary: \(preset.displayName)")
            } catch {
                logger.error("Failed to import \(preset.displayName): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - CSV Import
    /// Import vocabulary from a CSV file
    func importCSV(from url: URL, bookName: String, bookDescription: String?) async throws -> WordBook {
        let content = try String(contentsOf: url, encoding: .utf8)
        return try await importCSV(content: content, bookName: bookName, bookDescription: bookDescription)
    }

    /// Import vocabulary from CSV content string
    func importCSV(content: String, bookName: String, bookDescription: String?) async throws -> WordBook {
        var lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Remove header if present
        if lines.first?.lowercased().hasPrefix("word") == true {
            lines.removeFirst()
        }

        // Parse words
        var words: [Word] = []
        var errors: [String] = []

        for (index, line) in lines.enumerated() {
            let parts = parseCSVLine(line)

            guard parts.count >= 2 else {
                errors.append("Line \(index + 1): Invalid format, expected at least word and meaning")
                continue
            }

            let word = Word(
                bookId: "",  // Will be set after book creation
                word: parts[0].trimmingCharacters(in: .whitespaces),
                phonetic: parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil,
                meaning: parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : parts[1].trimmingCharacters(in: .whitespaces),
                sentence: parts.count > 3 ? parts[3].trimmingCharacters(in: .whitespaces) : nil,
                sentenceTranslation: parts.count > 4 ? parts[4].trimmingCharacters(in: .whitespaces) : nil
            )

            if word.word.isEmpty {
                errors.append("Line \(index + 1): Empty word")
                continue
            }

            words.append(word)
        }

        if !errors.isEmpty {
            logger.warning("CSV Import warnings: \(errors.prefix(5).joined(separator: "; "))")
        }

        // Create word book
        let book = WordBook(
            name: bookName,
            description: bookDescription,
            wordCount: words.count,
            isPreset: false
        )

        try DatabaseService.shared.createWordBook(book)

        // Update word book IDs and save
        let wordsWithBookId = words.map { word in
            Word(
                id: word.id,
                bookId: book.id,
                word: word.word,
                phonetic: word.phonetic,
                meaning: word.meaning,
                sentence: word.sentence
            )
        }

        try DatabaseService.shared.createWords(wordsWithBookId)

        return book
    }

    /// Parse a CSV line handling quoted values
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }

        result.append(current)
        return result
    }

    // MARK: - Manual Word Addition
    /// Add a single word to an existing book
    func addWord(to bookId: String, word: String, phonetic: String?, meaning: String, sentence: String?) throws {
        let newWord = Word(
            bookId: bookId,
            word: word,
            phonetic: phonetic,
            meaning: meaning,
            sentence: sentence
        )

        try DatabaseService.shared.createWord(newWord)

        // Update word count in book
        if var book = try DatabaseService.shared.fetchWordBook(byId: bookId) {
            book.wordCount += 1
            try DatabaseService.shared.updateWordBook(book)
        }
    }
}

// MARK: - Supporting Types
struct VocabularyFile: Codable {
    let name: String
    let description: String?
    let words: [VocabularyWord]
}

struct VocabularyWord: Codable {
    let word: String
    let phonetic: String?
    let meaning: String
    let sentence: String?
    let sentenceTranslation: String?
}

enum VocabImportError: Error, LocalizedError {
    case fileNotFound
    case invalidFormat
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "词汇文件未找到"
        case .invalidFormat:
            return "文件格式无效"
        case .importFailed(let reason):
            return "导入失败: \(reason)"
        }
    }
}
