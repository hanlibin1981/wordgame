import SwiftUI

/// Navigation destination types for LearningTabView
enum LearningNavDestination: Hashable {
    case levelSelection(WordBook)
    case game(book: WordBook, level: GameLevel)
    case review(book: WordBook)
}

/// Main tab view for the app navigation
struct MainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Learning Tab
            LearningTabView()
                .tabItem {
                    Label("学习", systemImage: "house.fill")
                }
                .tag(0)

            // Word Books Tab
            WordBookListView()
                .tabItem {
                    Label("词库", systemImage: "books.vertical")
                }
                .tag(1)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(2)
        }
        .frame(minWidth: 960, minHeight: 680)
    }
}

/// Learning tab with quick access to continue learning
struct LearningTabView: View {
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @AppStorage("defaultWordBookId") private var defaultWordBookId: String = ""
    @State private var navigationPath = NavigationPath()
    @StateObject private var gameVM = GameViewModel()
    @State private var isFindingLevel = false

    /// The word book used for "continue learning" — defaults to stored preference, falls back to first book.
    private var continueLearningBook: WordBook? {
        wordBookVM.wordBooks.first { $0.id == defaultWordBookId }
            ?? wordBookVM.wordBooks.first
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Welcome Header
                    welcomeHeader

                    // Continue Learning Card
                    if let continueBook = continueLearningBook {
                        continueLearningCard(book: continueBook, gameVM: gameVM, isFindingLevel: $isFindingLevel) { level in
                            navigationPath.append(LearningNavDestination.game(book: continueBook, level: level))
                        } onStartReview: {
                            navigationPath.append(LearningNavDestination.review(book: continueBook))
                        }
                    }

                    // All Word Books Grid
                    wordBooksGrid

                    Spacer()
                }
                .padding()
            }
            .background(Color.backgroundMain)
            .navigationTitle("背单词")
            .navigationDestination(for: LearningNavDestination.self) { destination in
                switch destination {
                case .levelSelection(let book):
                    LevelSelectionView(book: book, navigationPath: $navigationPath)
                case .game(let book, let level):
                    GameView(book: book, level: level, onContinueToNext: { nextBook, nextLevel in
                        navigationPath.append(LearningNavDestination.game(book: nextBook, level: nextLevel))
                    })
                case .review(let book):
                    ReviewView(book: book)
                }
            }
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("欢迎回来!")
                .font(DesignFont.largeTitle)

            Text("今天也要坚持学习哦")
                .font(DesignFont.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func continueLearningCard(book: WordBook, gameVM: GameViewModel, isFindingLevel: Binding<Bool>, onLevelFound: @escaping (GameLevel) -> Void, onStartReview: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("继续学习")
                    .font(DesignFont.headline)
                Spacer()
                Text(book.name)
                    .font(DesignFont.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                // 复习按钮
                Button(action: onStartReview) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("复习")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.warningOrange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                // 开始闯关按钮
                Button(action: {
                    isFindingLevel.wrappedValue = true
                    Task {
                        if let level = await gameVM.findCurrentLevel(for: book) {
                            await MainActor.run {
                                onLevelFound(level)
                                isFindingLevel.wrappedValue = false
                            }
                        } else {
                            await MainActor.run {
                                isFindingLevel.wrappedValue = false
                            }
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        if isFindingLevel.wrappedValue {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        Text(isFindingLevel.wrappedValue ? "加载中..." : "开始闯关")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primaryBlue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isFindingLevel.wrappedValue)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var wordBooksGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择词库")
                .font(DesignFont.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(wordBookVM.wordBooks) { book in
                    WordBookCard(book: book)
                        .onTapGesture {
                            navigationPath.append(LearningNavDestination.levelSelection(book))
                        }
                }
            }
        }
    }
}

/// Card view for a word book
struct WordBookCard: View {
    let book: WordBook

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: book.isPreset ? "star.fill" : "folder")
                    .font(.system(size: 13))
                    .foregroundColor(book.isPreset ? .warningOrange : .primaryBlue)

                Text(book.typeLabel)
                    .font(DesignFont.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(book.isPreset ? Color.warningOrange.opacity(0.1) : Color.primaryBlue.opacity(0.1))
                    .cornerRadius(4)
                Spacer()
            }

            Text(book.name)
                .font(DesignFont.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let description = book.description {
                Text(description)
                    .font(DesignFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            HStack {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 12))
                Text("\(book.wordCount) 词")
            }
            .font(DesignFont.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(minHeight: 120, alignment: .topLeading)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(
            color: isHovered ? Color.primaryBlue.opacity(0.15) : .black.opacity(0.05),
            radius: isHovered ? 12 : 4,
            x: 0,
            y: isHovered ? 6 : 2
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    MainView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(WordBookViewModel())
}
