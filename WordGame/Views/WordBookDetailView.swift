import SwiftUI

/// Detail view for a word book showing all words
struct WordBookDetailView: View {
    let book: WordBook
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @State private var showAddWord = false
    @State private var showLevelSelection = false
    @State private var selectedLevelForGame: GameLevel?
    @State private var searchText = ""
    @State private var selectedWord: Word?

    var filteredWords: [Word] {
        if searchText.isEmpty {
            return wordBookVM.words
        }
        return wordBookVM.words.filter {
            $0.word.localizedCaseInsensitiveContains(searchText) ||
            $0.meaning.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(book.name)
                            .font(DesignFont.title2)

                        HStack(spacing: 8) {
                            Text(book.typeLabel)
                                .font(DesignFont.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(book.isPreset ? Color.warningOrange.opacity(0.15) : Color.primaryBlue.opacity(0.15))
                                .cornerRadius(4)

                            Text("\(wordBookVM.words.count) 词")
                                .font(DesignFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button("开始学习") {
                        showLevelSelection = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let description = book.description {
                    Text(description)
                        .font(DesignFont.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color.backgroundMain)

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("搜索单词...", text: $searchText)
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding()

            // Words list
            List {
                ForEach(filteredWords) { word in
                    WordRow(word: word)
                        .onTapGesture {
                            selectedWord = word
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !book.isPreset {
                                Button(role: .destructive) {
                                    Task {
                                        try? await wordBookVM.deleteWord(word)
                                    }
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("词库详情")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    dismiss()
                }
            }

            if !book.isPreset {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddWord = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await wordBookVM.selectWordBook(book)
            }
        }
        .sheet(isPresented: $showAddWord) {
            AddWordView(bookId: book.id)
        }
        .sheet(item: $selectedWord) { word in
            WordDetailView(word: word)
        }
        .sheet(isPresented: $showLevelSelection) {
            LevelSelectionView(book: book, selectedLevel: $selectedLevelForGame)
        }
        .sheet(item: $selectedLevelForGame) { level in
            GameView(book: book, level: level)
        }
    }
}

/// Row view for a single word
struct WordRow: View {
    let word: Word

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.word)
                        .font(DesignFont.headline)

                    if let phonetic = word.phonetic, !phonetic.isEmpty {
                        Text(phonetic)
                            .font(DesignFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(word.meaning)
                    .font(DesignFont.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Mastery indicator
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(index < word.masteryLevel ? Color.successGreen : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// View for adding a single word to a book
struct AddWordView: View {
    let bookId: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @State private var word = ""
    @State private var phonetic = ""
    @State private var meaning = ""
    @State private var sentence = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("添加单词")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("单词 *")
                        .font(DesignFont.subheadline)
                    TextField("例如：abandon", text: $word)
                        .font(DesignFont.subheadline)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("音标（可选）")
                        .font(DesignFont.subheadline)
                    TextField("例如：əˈbændən", text: $phonetic)
                        .font(DesignFont.subheadline)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("释义 *")
                        .font(DesignFont.subheadline)
                    TextField("例如：v. 放弃；抛弃", text: $meaning)
                        .font(DesignFont.subheadline)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("例句（可选）")
                        .font(DesignFont.subheadline)
                    TextField("例如：Never abandon your dreams.", text: $sentence)
                        .font(DesignFont.subheadline)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.errorRed)
                    .font(DesignFont.caption)
            }

            Spacer()

            Button(action: saveWord) {
                if isSaving {
                    ProgressView()
                } else {
                    Text("添加")
                        .font(DesignFont.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(word.isEmpty || meaning.isEmpty ? Color.gray : Color.primaryBlue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(word.isEmpty || meaning.isEmpty || isSaving)
        }
        .padding()
        .frame(width: 400, height: 420)
    }

    private func saveWord() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                try await wordBookVM.addWord(
                    word: word,
                    phonetic: phonetic.isEmpty ? nil : phonetic,
                    meaning: meaning,
                    sentence: sentence.isEmpty ? nil : sentence
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

/// Detail view for a single word
struct WordDetailView: View {
    let word: Word
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioService = AudioService.shared

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("单词详情")
                    .font(DesignFont.title2)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
            }

            // Word card
            VStack(spacing: 16) {
                HStack {
                    Text(word.word)
                        .font(DesignFont.largeTitle)

                    Button(action: { audioService.speakWithSay(word.word) }) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(DesignFont.title2)
                    }
                    .buttonStyle(.bordered)
                }

                if let phonetic = word.phonetic, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(DesignFont.title3)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("释义")
                        .font(DesignFont.subheadline)
                        .foregroundStyle(.secondary)
                    Text(word.meaning)
                        .font(DesignFont.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let sentence = word.sentence, !sentence.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("例句")
                            .font(DesignFont.subheadline)
                            .foregroundStyle(.secondary)
                        Text(sentence)
                            .font(DesignFont.body)
                            .italic()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)

            // Mastery level
            VStack(spacing: 8) {
                Text("掌握程度")
                    .font(DesignFont.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(0..<6) { level in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(level <= word.masteryLevel ? Color.successGreen : Color.gray.opacity(0.3))
                                .frame(width: 20, height: 20)

                            Text("\(level)")
                                .font(DesignFont.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Wrong count
            HStack {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(Color.errorRed)
                Text("错误次数: \(word.wrongCount)")
                    .font(DesignFont.subheadline)
            }
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

#Preview {
    WordBookDetailView(book: WordBook(name: "测试词库", wordCount: 100))
        .environmentObject(WordBookViewModel())
}
