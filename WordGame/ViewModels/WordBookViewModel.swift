import Foundation
import SwiftUI

/// ViewModel for word book management
@MainActor
final class WordBookViewModel: ObservableObject {
    @Published var wordBooks: [WordBook] = []
    @Published var selectedBook: WordBook?
    @Published var words: [Word] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isInitialized = false

    private let database = DatabaseService.shared
    private let vocabImport = VocabImportService.shared

    /// Initialize the app: load word books and import presets if needed
    func initializeIfNeeded() async {
        guard !isInitialized else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load existing word books
            wordBooks = try database.fetchAllWordBooks()

            // Always ensure preset vocabularies exist (idempotent skip if already imported).
            await vocabImport.initializePresetVocabularies()
            wordBooks = try database.fetchAllWordBooks()

            isInitialized = true
        } catch {
            errorMessage = "初始化失败: \(error.localizedDescription)"
        }
    }

    /// Refresh word books list
    func refreshWordBooks() async {
        isLoading = true
        defer { isLoading = false }

        do {
            wordBooks = try database.fetchAllWordBooks()
        } catch {
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }

    /// Select a word book and load its words
    func selectWordBook(_ book: WordBook) async {
        selectedBook = book
        isLoading = true
        defer { isLoading = false }

        do {
            words = try database.fetchWords(forBookId: book.id)
        } catch {
            errorMessage = "加载单词失败: \(error.localizedDescription)"
        }
    }

    /// Clear selection
    func clearSelection() {
        selectedBook = nil
        words = []
    }

    /// Create a new empty word book
    func createWordBook(name: String, description: String?) async throws {
        let book = WordBook(
            name: name,
            description: description,
            isPreset: false
        )

        try database.createWordBook(book)
        await refreshWordBooks()
    }

    /// Delete a word book
    func deleteWordBook(_ book: WordBook) async throws {
        guard !book.isPreset else {
            throw WordBookError.cannotDeletePreset
        }

        try database.deleteWordBook(byId: book.id)

        if selectedBook?.id == book.id {
            clearSelection()
        }

        await refreshWordBooks()
    }

    /// Add a word to the selected book
    func addWord(word: String, phonetic: String?, meaning: String, sentence: String?) async throws {
        guard let book = selectedBook else {
            throw WordBookError.noBookSelected
        }

        try vocabImport.addWord(
            to: book.id,
            word: word,
            phonetic: phonetic,
            meaning: meaning,
            sentence: sentence
        )

        // Refresh words and book
        words = try database.fetchWords(forBookId: book.id)
        if var updatedBook = try database.fetchWordBook(byId: book.id) {
            updatedBook.wordCount = words.count
            try database.updateWordBook(updatedBook)
            selectedBook = updatedBook
        }

        await refreshWordBooks()
    }

    /// Delete a word
    func deleteWord(_ word: Word) async throws {
        guard let book = selectedBook else { return }

        try database.deleteWord(byId: word.id)

        // Refresh
        words = try database.fetchWords(forBookId: book.id)
        if var updatedBook = try database.fetchWordBook(byId: book.id) {
            updatedBook.wordCount = words.count
            try database.updateWordBook(updatedBook)
            selectedBook = updatedBook
        }
    }

    /// Import CSV file to create a new word book
    func importCSV(from url: URL, bookName: String, description: String?) async throws {
        let book = try await vocabImport.importCSV(from: url, bookName: bookName, bookDescription: description)
        await refreshWordBooks()
        selectedBook = book
        words = try database.fetchWords(forBookId: book.id)
    }
}

// MARK: - Errors
enum WordBookError: Error, LocalizedError {
    case cannotDeletePreset
    case noBookSelected

    var errorDescription: String? {
        switch self {
        case .cannotDeletePreset:
            return "无法删除预置词库"
        case .noBookSelected:
            return "未选择词库"
        }
    }
}
